#!/usr/bin/env node
/**
 * One-time migration: move legacy `users/{uid}.phone` into the owner-only
 * `users/{uid}/private/contact` document and delete it from the public profile.
 *
 *   DRY RUN (default, writes nothing):   node scripts/migrate_user_phone_to_private.js
 *   Apply:                               node scripts/migrate_user_phone_to_private.js --apply
 *
 * SAFETY: refuses to run against a real project unless FIRESTORE_EMULATOR_HOST is set
 * or --allow-production is passed explicitly. Idempotent: an existing private phone is
 * never overwritten; a profile phone is only removed once the private copy holds it.
 */
const path = require("path");
const admin = require(path.join(__dirname, "..", "functions", "node_modules", "firebase-admin"));
const {FieldValue} = require(path.join(__dirname, "..", "functions", "node_modules", "firebase-admin", "lib", "firestore"));

const apply = process.argv.includes("--apply");
const allowProd = process.argv.includes("--allow-production");
if (!process.env.FIRESTORE_EMULATOR_HOST && !allowProd) {
  console.error("Refusing to run against a real Firebase project without --allow-production.");
  process.exit(2);
}
admin.initializeApp({projectId: process.env.GCLOUD_PROJECT || undefined});
const db = admin.firestore();

(async () => {
  const stats = {scanned: 0, withPhone: 0, moved: 0, alreadyPrivate: 0, conflicts: 0, cleared: 0};
  const conflicts = [];
  let last = null;
  for (;;) {
    let q = db.collection("users").orderBy("__name__").limit(200);
    if (last) q = q.startAfter(last);
    const snap = await q.get();
    if (snap.empty) break;
    for (const d of snap.docs) {
      last = d;
      stats.scanned++;
      const phone = d.get("phone");
      if (typeof phone !== "string" || phone === "") continue;
      stats.withPhone++;
      const ref = d.ref.collection("private").doc("contact");
      const existing = await ref.get();
      const priv = existing.exists ? existing.get("phone") : null;
      if (priv && priv !== phone) { stats.conflicts++; conflicts.push(d.id); continue; } // needs a human decision
      if (priv) stats.alreadyPrivate++; else stats.moved++;
      if (apply) {
        if (!priv) await ref.set({phone, updatedAt: FieldValue.serverTimestamp()});
        await d.ref.update({phone: FieldValue.delete()});
        stats.cleared++;
      }
    }
  }
  console.log(JSON.stringify({mode: apply ? "APPLY" : "DRY-RUN", ...stats, conflictUids: conflicts}, null, 2));
})().catch((e) => { console.error(e); process.exit(1); });
