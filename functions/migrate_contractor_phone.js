/**
 * One-time migration: Move contractor phone from public jobs collection to protected contractorContacts.
 *
 * SAFETY FIRST: This function has a DRY-RUN mode that makes NO database changes.
 * Run DRY-RUN first to see exactly what will be migrated/cleaned.
 *
 * Usage:
 *   DRY-RUN (safe):
 *     firebase functions:call migrateContractorPhone --data '{"dryRun": true, "batchSize": 100, "maxBatches": 10}'
 *
 *   REAL MIGRATION (after verifying DRY-RUN output):
 *     firebase functions:call migrateContractorPhone --data '{"dryRun": false, "batchSize": 50, "maxBatches": 0}'
 *
 * The function is idempotent: safe to stop, resume, or re-run.
 */

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

const db = admin.firestore();
const MAX_BATCH_WRITES = 500; // Firestore batch limit
const DEFAULT_BATCH_SIZE = 50;

/**
 * Validate and extract contractor contact data.
 * Returns null if invalid, otherwise {contractorId, contractorName, contractorPhone}
 */
async function extractContractorData(jobDoc) {
  const data = jobDoc.data();
  if (!data) return null;

  const contractorId = data.postedBy;
  if (!contractorId || typeof contractorId !== 'string') {
    return null; // No postedBy field
  }

  // Fetch contractor from users collection
  let contractorData;
  try {
    const userSnap = await db.collection("users").doc(contractorId).get();
    if (!userSnap.exists) {
      return null; // User not found
    }
    contractorData = userSnap.data();
  } catch (error) {
    throw new Error(`Failed to fetch user ${contractorId}: ${error.message}`);
  }

  const contractorName = contractorData.fullName || data.contractorName || '';
  const contractorPhone = contractorData.phone || '';

  return {
    contractorId,
    contractorName,
    contractorPhone,
  };
}

/**
 * Process a single job: create protected doc if needed, then remove old field.
 * Returns {status, reason?, oldPhone?}:
 *   'migrated' - created contractorContacts, removed old field
 *   'already_migrated' - protected doc existed, old field already gone
 *   'protected_exists' - protected doc exists, old field still in job (needs cleanup)
 *   'skipped' - no postedBy, missing contractor, or malformed job
 *   'failed' - error occurred
 */
async function migrateJob(jobId, jobDoc, batch, dryRun) {
  try {
    const extractedData = await extractContractorData(jobDoc);
    if (!extractedData) {
      return { status: 'skipped', reason: 'no_contractor_data' };
    }

    const { contractorId, contractorName, contractorPhone } = extractedData;
    const jobData = jobDoc.data();
    const hasOldField = typeof jobData.contractorPhone === 'string' && jobData.contractorPhone.length > 0;

    // Check if protected doc already exists
    const contactRef = db.collection('contractorContacts').doc(jobId);
    const contactSnap = await contactRef.get();

    if (contactSnap.exists) {
      // Protected doc exists; check if old field needs cleanup
      if (hasOldField) {
        // Old field still in public doc; clean it up only
        if (!dryRun) {
          batch.update(jobDoc.ref, { contractorPhone: '' });
        }
        return {
          status: 'protected_exists',
          reason: 'cleaned_old_field',
          oldPhone: jobData.contractorPhone,
        };
      }
      // Both migration and cleanup already done
      return { status: 'already_migrated' };
    }

    // Create protected doc
    const contactData = {
      contractorId,
      contractorName,
      contractorPhone,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (!dryRun) {
      batch.set(contactRef, contactData);

      // Only remove old field if creation would succeed
      if (hasOldField) {
        batch.update(jobDoc.ref, { contractorPhone: '' });
      }
    }

    return {
      status: 'migrated',
      oldPhone: jobData.contractorPhone || '(not present)',
    };
  } catch (error) {
    return {
      status: 'failed',
      reason: error.message,
    };
  }
}

/**
 * Main migration: process all jobs in batches.
 */
exports.migrateContractorPhone = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in first.");
  }
  if (!request.auth.token.admin) {
    throw new HttpsError("permission-denied", "Admin role required for contractor phone migration.");
  }

  console.log(`Migration initiated by admin: ${request.auth.uid}`);

  const {
    dryRun = true,
    batchSize = DEFAULT_BATCH_SIZE,
    maxBatches = 10,
  } = request.data;

  console.log(`\n=== Contractor Phone Privacy Migration ===`);
  console.log(`Mode: ${dryRun ? 'DRY-RUN (no changes)' : 'REAL MIGRATION'}`);
  console.log(`Batch size: ${batchSize}`);
  console.log(`Max batches to process: ${maxBatches === 0 ? 'unlimited' : maxBatches}`);
  console.log(`Timestamp: ${new Date().toISOString()}\n`);

  const stats = {
    scanned: 0,
    migrated: 0,
    alreadyMigrated: 0,
    protectedExists: 0,
    skipped: 0,
    failed: 0,
    errors: [],
  };

  let batchCount = 0;
  let lastDocId = null;
  let hasMore = true;

  while (hasMore && (maxBatches === 0 || batchCount < maxBatches)) {
    try {
      // Query next batch of jobs
      let query = db.collection('jobs').orderBy('__name__').limit(batchSize);
      if (lastDocId) {
        // Resume from last processed job
        const startDoc = await db.collection('jobs').doc(lastDocId).get();
        if (startDoc.exists) {
          query = query.startAfter(startDoc);
        }
      }

      const snapshot = await query.get();
      if (snapshot.empty) {
        hasMore = false;
        break;
      }

      const docs = snapshot.docs;
      const batch = db.batch();
      let batchWriteCount = 0;

      // Process each job in this batch
      for (const jobDoc of docs) {
        const jobId = jobDoc.id;
        stats.scanned++;

        const result = await migrateJob(jobId, jobDoc, batch, dryRun);
        stats[result.status]++;

        if (result.status === 'failed') {
          stats.errors.push(`Job ${jobId}: ${result.reason}`);
          console.warn(`[FAILED] Job ${jobId}: ${result.reason}`);
        } else if (result.status === 'migrated' || result.status === 'protected_exists') {
          batchWriteCount += dryRun ? 0 : (result.status === 'migrated' ? 2 : 1);
          console.log(`[${result.status.toUpperCase()}] Job ${jobId}: phone ${result.oldPhone || 'N/A'}`);
        } else {
          console.log(`[${result.status.toUpperCase()}] Job ${jobId}: ${result.reason || 'no action'}`);
        }

        lastDocId = jobId;
      }

      // Commit batch writes (only if not dry-run)
      if (!dryRun && batchWriteCount > 0) {
        await batch.commit();
        console.log(`Committed batch ${batchCount + 1} (${batchWriteCount} writes)`);
      }

      batchCount++;

      if (docs.length < batchSize) {
        hasMore = false;
      }
    } catch (error) {
      const errorMsg = `Batch ${batchCount + 1} failed: ${error.message}`;
      stats.errors.push(errorMsg);
      console.error(errorMsg);
      // Continue with next batch instead of aborting
    }
  }

  // Summary report
  console.log(`\n=== MIGRATION SUMMARY ===`);
  console.log(`Total scanned: ${stats.scanned}`);
  console.log(`Migrated (new): ${stats.migrated}`);
  console.log(`Already migrated: ${stats.alreadyMigrated}`);
  console.log(`Protected exists (cleanup): ${stats.protectedExists}`);
  console.log(`Skipped: ${stats.skipped}`);
  console.log(`Failed: ${stats.failed}`);
  if (stats.errors.length > 0) {
    console.log(`\nErrors encountered:`);
    stats.errors.slice(0, 10).forEach(e => console.log(`  - ${e}`));
    if (stats.errors.length > 10) {
      console.log(`  ... and ${stats.errors.length - 10} more`);
    }
  }

  // Return result to user
  return {
    dryRun,
    scanned: stats.scanned,
    migrated: stats.migrated,
    alreadyMigrated: stats.alreadyMigrated,
    protectedExists: stats.protectedExists,
    skipped: stats.skipped,
    failed: stats.failed,
    errors: stats.errors.slice(0, 5),
    nextSteps: !dryRun
      ? 'Run verification: firebase functions:call verifyMigration'
      : 'Review results above, then run real migration: firebase functions:call migrateContractorPhone --data \'{"dryRun": false}\'',
  };
});

/**
 * Verification function: audit all jobs to ensure migration is complete.
 * Reports any jobs still having contractorPhone in public collection.
 * ENHANCED: Detects conflicts, empty phones, and orphaned docs.
 */
exports.verifyMigration = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in first.");
  }
  if (!request.auth.token.admin) {
    throw new HttpsError("permission-denied", "Admin role required for verification.");
  }

  console.log(`\n=== Verification: Checking all jobs (Admin: ${request.auth.uid}) ===\n`);

  const issues = [];
  const stats = {
    total: 0,
    cleanJobs: 0,
    jobsWithPhone: 0,
    jobsWithoutProtected: 0,
    jobsWithEmptyPhone: 0,
    jobsWithConflictingPhone: 0,
    orphanedProtected: 0,
  };

  let lastDocId = null;
  let hasMore = true;
  const batchSize = 100;

  // Phase 1: Check all jobs
  while (hasMore) {
    try {
      let query = db.collection('jobs').orderBy('__name__').limit(batchSize);
      if (lastDocId) {
        const startDoc = await db.collection('jobs').doc(lastDocId).get();
        if (startDoc.exists) {
          query = query.startAfter(startDoc);
        }
      }

      const snapshot = await query.get();
      if (snapshot.empty) break;

      for (const jobDoc of snapshot.docs) {
        const jobId = jobDoc.id;
        const jobData = jobDoc.data();
        stats.total++;

        const hasOldPhone = typeof jobData.contractorPhone === 'string' && jobData.contractorPhone.length > 0;
        const contactSnap = await db.collection('contractorContacts').doc(jobId).get();

        // Check 1: Old phone field still present
        if (hasOldPhone) {
          stats.jobsWithPhone++;
          issues.push({
            jobId,
            issue: 'Old field still in public collection',
            phone: jobData.contractorPhone,
            protectedExists: contactSnap.exists,
            severity: 'HIGH',
          });
        }

        // Check 2: Missing protected doc
        if (!contactSnap.exists && jobData.postedBy) {
          stats.jobsWithoutProtected++;
          if (hasOldPhone) {
            // Already logged in Check 1
          } else {
            issues.push({
              jobId,
              issue: 'No protected contractorContacts document',
              contractor: jobData.postedBy,
              severity: 'MEDIUM',
            });
          }
        }

        // Check 3: Protected doc exists - check for conflicts/empty phones
        if (contactSnap.exists) {
          const protectedData = contactSnap.data();
          const oldPhone = jobData.contractorPhone || '';
          const newPhone = protectedData.contractorPhone || '';

          // Conflict detection: old and new phones differ
          if (oldPhone && newPhone && oldPhone !== newPhone) {
            stats.jobsWithConflictingPhone++;
            issues.push({
              jobId,
              issue: 'CONFLICT: Old and protected phone numbers differ',
              oldPhone,
              newPhone,
              severity: 'HIGH',
            });
          }

          // Empty phone detection: protected doc has no phone
          if (!newPhone && jobData.postedBy) {
            stats.jobsWithEmptyPhone++;
            issues.push({
              jobId,
              issue: 'Protected doc has empty phone number',
              contractor: jobData.postedBy,
              severity: 'MEDIUM',
            });
          }

          // Clean job: no old field, protected doc exists with phone
          if (!hasOldPhone && newPhone) {
            stats.cleanJobs++;
          }
        }

        lastDocId = jobId;
      }

      if (snapshot.docs.length < batchSize) {
        hasMore = false;
      }
    } catch (error) {
      throw new HttpsError('internal', `Verification failed: ${error.message}`);
    }
  }

  // Phase 2: Check for orphaned protected documents
  console.log(`\nChecking for orphaned contractorContacts documents...`);
  lastDocId = null;
  hasMore = true;

  while (hasMore) {
    try {
      let orphanQuery = db.collection('contractorContacts')
          .orderBy('__name__')
          .limit(100);

      if (lastDocId) {
        const startDoc = await db.collection('contractorContacts').doc(lastDocId).get();
        if (startDoc.exists) {
          orphanQuery = orphanQuery.startAfter(startDoc);
        }
      }

      const orphanSnapshot = await orphanQuery.get();
      if (orphanSnapshot.empty) {
        hasMore = false;
        break;
      }

      for (const orphanDoc of orphanSnapshot.docs) {
        const jobId = orphanDoc.id;
        const jobSnap = await db.collection('jobs').doc(jobId).get();

        if (!jobSnap.exists) {
          stats.orphanedProtected++;
          issues.push({
            jobId,
            issue: 'ORPHANED: Protected doc exists but job does not',
            note: 'Manual cleanup needed',
            severity: 'LOW',
          });
        }
        lastDocId = jobId;
      }

      if (orphanSnapshot.docs.length < 100) {
        hasMore = false;
      }
    } catch (error) {
      console.error(`Orphan check failed: ${error.message}`);
      // Don't throw - orphan check is secondary
    }
  }

  // Report findings
  console.log(`\n=== Verification Results ===`);
  console.log(`Total jobs checked: ${stats.total}`);
  console.log(`Clean jobs: ${stats.cleanJobs}`);
  console.log(`Jobs with old phone field: ${stats.jobsWithPhone}`);
  console.log(`Jobs missing protected doc: ${stats.jobsWithoutProtected}`);
  console.log(`Jobs with empty phone: ${stats.jobsWithEmptyPhone}`);
  console.log(`Jobs with CONFLICTING phones: ${stats.jobsWithConflictingPhone}`);
  console.log(`Orphaned protected docs: ${stats.orphanedProtected}`);

  if (issues.length > 0) {
    console.log(`\n⚠️  ISSUES FOUND (${issues.length} total):`);
    issues.slice(0, 20).forEach(issue => {
      console.log(`  [${issue.severity}] Job ${issue.jobId}: ${issue.issue}`);
      if (issue.oldPhone) console.log(`       Old: ${issue.oldPhone}`);
      if (issue.newPhone) console.log(`       New: ${issue.newPhone}`);
      if (issue.phone) console.log(`       Phone: ${issue.phone}`);
      if (issue.note) console.log(`       Note: ${issue.note}`);
    });
    if (issues.length > 20) {
      console.log(`  ... and ${issues.length - 20} more issues`);
    }
  } else {
    console.log(`\n✅ All jobs are clean! Migration complete.`);
  }

  return {
    total: stats.total,
    cleanJobs: stats.cleanJobs,
    jobsWithPhone: stats.jobsWithPhone,
    jobsWithoutProtected: stats.jobsWithoutProtected,
    jobsWithEmptyPhone: stats.jobsWithEmptyPhone,
    jobsWithConflictingPhone: stats.jobsWithConflictingPhone,
    orphanedProtected: stats.orphanedProtected,
    issuesFound: issues.length,
    issues: issues.slice(0, 20),
    status: issues.length === 0 ? 'COMPLETE' : 'ISSUES_FOUND',
    summary: `${stats.total} total jobs, ${stats.cleanJobs} clean, ${issues.length} issues found`,
  };
});

/**
 * Cleanup function: Force-remove contractorPhone from all jobs that have it.
 * Use only after verifying migration is complete.
 */
exports.cleanupContractorPhone = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in first.");
  }
  if (!request.auth.token.admin) {
    throw new HttpsError("permission-denied", "Admin role required for cleanup.");
  }

  const { confirm = false } = request.data;
  if (!confirm) {
    throw new HttpsError('invalid-argument', 'Set confirm: true to proceed');
  }

  console.log(`\n=== Final Cleanup: Removing contractorPhone from all jobs (Admin: ${request.auth.uid}) ===\n`);

  let cleaned = 0;
  let lastDocId = null;
  let hasMore = true;
  const batchSize = 50;

  while (hasMore) {
    try {
      let query = db.collection('jobs')
          .where('contractorPhone', '!=', '')
          .orderBy('__name__')
          .limit(batchSize);

      if (lastDocId) {
        const startDoc = await db.collection('jobs').doc(lastDocId).get();
        if (startDoc.exists) {
          query = query.startAfter(startDoc);
        }
      }

      const snapshot = await query.get();
      if (snapshot.empty) break;

      const batch = db.batch();
      for (const jobDoc of snapshot.docs) {
        batch.update(jobDoc.ref, { contractorPhone: '' });
        lastDocId = jobDoc.id;
        cleaned++;
      }

      await batch.commit();
      console.log(`Cleaned batch of ${snapshot.docs.length} jobs`);

      if (snapshot.docs.length < batchSize) {
        hasMore = false;
      }
    } catch (error) {
      throw new HttpsError('internal', `Cleanup failed: ${error.message}`);
    }
  }

  console.log(`\n✅ Cleanup complete: ${cleaned} jobs cleaned`);

  return { cleaned };
});
