/**
 * UniShram Cloud Functions.
 *
 * Anything a client must not be able to forge lives here: applicant counts,
 * rating averages, suspensions, and the cascade that removes a user's data
 * when they delete their account.
 */
const {onDocumentCreated, onDocumentUpdated, onDocumentDeleted} = require("firebase-functions/v2/firestore");
const {onCall, onRequest, HttpsError} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {setGlobalOptions} = require("firebase-functions/v2");
const admin = require("firebase-admin");
const {FieldValue, Timestamp} = require("firebase-admin/firestore");

admin.initializeApp();
setGlobalOptions({region: "asia-south1", maxInstances: 10});

const db = admin.firestore();
const messaging = admin.messaging();

/** Sends a push to every device a user has registered. */
async function notify(uid, notification, data = {}) {
  const tokensSnap = await db.collection("users").doc(uid).collection("tokens").get();
  const tokens = tokensSnap.docs.map((d) => d.id);
  if (tokens.length === 0) return;

  const response = await messaging.sendEachForMulticast({
    tokens,
    notification,
    data,
    android: {priority: "high", notification: {channelId: "unishram_default"}},
    apns: {payload: {aps: {sound: "default"}}},
  });

  // Drop tokens the device no longer accepts, so the list cannot grow stale.
  const stale = [];
  response.responses.forEach((r, i) => {
    const code = r.error && r.error.code;
    if (code === "messaging/registration-token-not-registered" ||
        code === "messaging/invalid-registration-token") {
      stale.push(tokens[i]);
    }
  });
  await Promise.all(stale.map((t) =>
    db.collection("users").doc(uid).collection("tokens").doc(t).delete()));
}

/**
 * A worker applied: bump the job's applicant tally and tell the contractor.
 * The count is server-only — firestore.rules blocks clients from touching
 * `applicantCount` directly, so this trigger (running with admin rights) is
 * the only place it ever changes.
 */
exports.onApplication = onDocumentCreated("applications/{applicationId}", async (event) => {
  const app = event.data && event.data.data();
  if (!app) return;

  const jobRef = db.collection("jobs").doc(app.jobId);
  await jobRef.update({applicantCount: FieldValue.increment(1)});

  const jobSnap = await jobRef.get();
  const job = jobSnap.data() || {};

  await notify(app.contractorId, {
    title: "New applicant",
    body: `${app.workerName || "A worker"} applied for ${job.title || "your job"}`,
  }, {type: "application", jobId: app.jobId});
});

/** A message arrived: tell whoever did not send it. Rate-limited to prevent spam. */
exports.onMessage = onDocumentCreated("threads/{threadId}/messages/{messageId}", async (event) => {
  const message = event.data && event.data.data();
  if (!message) return;

  const threadSnap = await db.collection("threads").doc(event.params.threadId).get();
  const thread = threadSnap.data();
  if (!thread) return;

  const recipient = (thread.participants || []).find((p) => p !== message.senderId);
  if (!recipient) return;

  // Rate limiting: max 10 messages per minute per sender per thread
  const now = Timestamp.now();
  const oneMinuteAgo = Timestamp.fromMillis(now.toMillis() - 60000);
  const recentMessages = await db.collection("threads").doc(event.params.threadId)
      .collection("messages")
      .where("senderId", "==", message.senderId)
      .where("sentAt", ">", oneMinuteAgo)
      .count()
      .get();

  if (recentMessages.data().count > 10) {
    console.warn("Rate limit: User sending too many messages", {
      userId: message.senderId,
      threadId: event.params.threadId,
      count: recentMessages.data().count,
    });
    return; // Silently drop the message
  }

  const senderName = (thread.names || {})[message.senderId] || "New message";
  await notify(recipient, {
    title: senderName,
    body: message.text.slice(0, 120),
  }, {type: "message", threadId: event.params.threadId});
});

/**
 * Wage protection, enforced server-side. A job posted below the state legal
 * minimum for its skill category is flagged on the document itself, so the
 * warning cannot be bypassed by a modified client.
 */
const {minimumWageFor} = require("./min_wage");

exports.onJobPosted = onDocumentCreated("jobs/{jobId}", async (event) => {
  const job = event.data && event.data.data();
  if (!job) return;

  const minimum = minimumWageFor(job.state, job.skill);

  await event.data.ref.update({
    minWageAtPost: minimum,
    belowMinimumWage: Number(job.wage) < minimum,
  });

  // Store contractor contact info in restricted collection (privacy protection)
  if (job.postedBy) {
    const contractorDoc = await db.collection("users").doc(job.postedBy).get();
    const contractorData = contractorDoc.data() || {};
    // The number lives in the owner-only private doc; the profile field is a legacy fallback.
    const contactDoc = await db.collection("users").doc(job.postedBy).collection("private").doc("contact").get();
    const contractorPhone = (contactDoc.exists && contactDoc.get("phone")) || contractorData.phone || '';
    await db.collection("contractorContacts").doc(event.params.jobId).set({
      contractorId: job.postedBy,
      contractorName: job.contractorName || contractorData.fullName || '',
      contractorPhone,
      createdAt: FieldValue.serverTimestamp(),
    });
  }

  // The post cooldown (users/{uid}.lastJobPostedAt) is stamped by the `postJob` callable, atomically with the
  // job create — not here — so parallel posts cannot slip through before an asynchronous trigger runs.
});

/** Keeps a user's rating average honest — clients never write it. */
exports.onReview = onDocumentCreated("reviews/{reviewId}", async (event) => {
  const review = event.data && event.data.data();
  if (!review) return;

  const userRef = db.collection("users").doc(review.aboutUserId);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(userRef);
    if (!snap.exists) return;
    const data = snap.data();
    const count = (data.ratingCount || 0) + 1;
    const total = (data.ratingAverage || 0) * (data.ratingCount || 0) + review.rating;
    tx.update(userRef, {
      ratingCount: count,
      ratingAverage: Math.round((total / count) * 10) / 10,
    });
  });
});

/**
 * Account deletion, as required by both stores. Removes the profile, jobs (and everyone's applications to
 * them), the user's own applications, listings, private details, photos and finally the auth user.
 *
 * Safe to run again: every step is idempotent and the Auth user is removed LAST, so if a call fails partway
 * the user is still signed in and can simply tap Delete again.
 *
 * Not removed here: chats, reviews and reports.
 */
// invoker "public" lets the app reach the function at all (Cloud Run level); the Firebase sign-in check below
// still decides who may delete — and only ever their own account. Without it Cloud Run refused every call.
exports.deleteAccount = onCall({invoker: "public"}, async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in first.");

  // Delete every document a query matches, in pages, together with its subcollections.
  const deleteWhere = async (query) => {
    for (;;) {
      const snap = await query.limit(200).get();
      if (snap.empty) return;
      for (const d of snap.docs) await db.recursiveDelete(d.ref);
    }
  };

  // 1. The user's jobs: everyone's applications to them, the hidden contact copy, the job.
  const myJobs = await db.collection("jobs").where("postedBy", "==", uid).get();
  for (const job of myJobs.docs) {
    await deleteWhere(db.collection("applications").where("jobId", "==", job.id));
    await db.doc(`contractorContacts/${job.id}`).delete();
    await job.ref.delete();
  }

  // 2. Everything else that belongs to, or names, this user.
  await deleteWhere(db.collection("applications").where("workerId", "==", uid));
  await deleteWhere(db.collection("applications").where("contractorId", "==", uid));
  await deleteWhere(db.collection("listings").where("vendorId", "==", uid));

  try {
    await admin.storage().bucket().deleteFiles({prefix: `users/${uid}/`});
  } catch (e) {
    console.error("storage cleanup failed", e);
  }

  // 3. The profile with all its subcollections (tokens, private contact + terms, block list), then the login.
  await db.recursiveDelete(db.collection("users").doc(uid));
  try {
    await admin.auth().deleteUser(uid);
  } catch (e) {
    if (!e || e.code !== "auth/user-not-found") throw e;
  }

  return {ok: true};
});

/**
 * Revoke a user's session immediately (e.g., on abuse detection).
 * Client checks this flag on every app resume.
 */
exports.revokeUserSession = onCall(async (request) => {
  const uid = request.auth && request.auth.uid;
  const targetUid = request.data.uid;

  // Only the user themselves can revoke their own session
  // (admins can revoke others only via Firebase CLI/Admin SDK, not client-callable)
  if (!uid) throw new HttpsError("unauthenticated", "Sign in first.");
  if (uid !== targetUid) {
    throw new HttpsError(
      "permission-denied",
      "You can only revoke your own session. Admin session revocation requires server-side authorization."
    );
  }

  await db.collection("users").doc(targetUid).set(
    {sessionRevoked: true, revokedAt: FieldValue.serverTimestamp()},
    {merge: true}
  );

  return {ok: true};
});

// Two-strike moderation. A strike is a report from someone who has actually
// dealt with the reported person (an application between them, or a direct
// chat) — a stranger cannot put a strike on anyone. One person counts once
// however often they report. Strikes expire after STRIKE_WINDOW_DAYS.
//   1 strike  -> warning (push + a card the person must acknowledge)
//   2 strikes -> account paused for BAN_DAYS, open jobs closed
//   3 strikes -> suspended until a moderator reviews it
// Who reported whom lives only in moderationLedger/{uid} (no client access);
// the person sees users/{uid}/private/moderation: counts, reasons and dates.
const STRIKE_WINDOW_DAYS = 90;
const BAN_DAYS = 7;
const DAY_MS = 24 * 60 * 60 * 1000;

// Reasons that mean the job itself is a trap — it doesn't exist, or it is a
// front for collecting "registration fees" from workers. This many different
// reporters close the job for everyone, whatever the poster's strikes.
const JOB_FRAUD_REASONS = ["fake_job", "asked_money", "scam"];
const JOB_FRAUD_CLOSE_THRESHOLD = 2;

const reasonsOf = (data) => Array.isArray(data && data.reasons) ? data.reasons : [];

/**
 * Closes an open job and marks why, so the poster cannot reopen it (see the
 * `moderationHold` check in the jobs rule). A moderator clears the hold.
 */
async function holdJob(ref, hold) {
  await db.runTransaction(async (tx) => {
    const job = await tx.get(ref);
    if (!job.exists || job.get("status") !== "open") return;
    tx.update(ref, {status: "closed", moderationHold: hold, moderationHoldAt: FieldValue.serverTimestamp()});
  });
}

async function holdOpenJobsOf(uid, hold) {
  // Filter status in code rather than a second where(): no composite index.
  const jobs = await db.collection("jobs").where("postedBy", "==", uid).get();
  await Promise.all(jobs.docs
      .filter((d) => d.get("status") === "open")
      .map((d) => holdJob(d.ref, hold)));
}

/** Whether [a] and [b] have dealt with each other: an application or a direct chat. */
async function haveDealtWith(a, b) {
  const apps = (worker, hirer) => db.collection("applications")
      .where("workerId", "==", worker).where("contractorId", "==", hirer).limit(1).get();
  const [one, other] = await Promise.all([apps(a, b), apps(b, a)]);
  if (!one.empty || !other.empty) return true;
  const [lo, hi] = a < b ? [a, b] : [b, a];
  return (await db.collection("threads").doc(`direct_${lo}_${hi}`).get()).exists;
}

const moderationView = (uid) => db.collection("users").doc(uid).collection("private").doc("moderation");
const moderationLedger = (uid) => db.collection("moderationLedger").doc(uid);

/**
 * Adds a strike from [reporterId] against [uid] and applies the step it
 * reaches. Returns the outcome, or null when it is not a new strike.
 */
async function addStrike(uid, reporterId, reportId, reasons) {
  return db.runTransaction(async (tx) => {
    const ledgerRef = moderationLedger(uid);
    const ledger = await tx.get(ledgerRef);
    const now = Date.now();
    const all = (ledger.exists && ledger.get("strikes")) || [];
    const active = all.filter((st) => st.at.toMillis() > now - STRIKE_WINDOW_DAYS * DAY_MS);
    if (active.some((st) => st.reporterId === reporterId)) return null;
    const previous = (ledger.exists && ledger.get("status")) || "clear";

    const strike = {reporterId, reportId, reasons, at: Timestamp.fromMillis(now)};
    const strikes = [...active, strike];
    const count = strikes.length;
    // A permanent suspension is only ever lifted by a moderator.
    const status = previous === "suspended" || count >= 3 ? "suspended" : count === 2 ? "banned" : "warned";
    const bannedUntil = status === "banned" ? Timestamp.fromMillis(now + BAN_DAYS * DAY_MS) : null;

    tx.set(ledgerRef, {
      strikes: [...all, strike], status, bannedUntil, updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    tx.set(moderationView(uid), {
      status,
      strikeTimes: strikes.map((st) => st.at),
      lastReasons: reasons,
      bannedUntil,
      noticeAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    if (status !== "warned") {
      tx.set(db.collection("users").doc(uid), {suspended: true}, {merge: true});
    }
    return {status, count, bannedUntil};
  });
}

const MODERATION_PUSH = {
  warned: {
    title: "Warning on your UniShram account / आपके खाते पर चेतावनी",
    body: "Someone you worked with reported a problem. Another report will pause your account for 7 days. " +
      "किसी ने आपकी शिकायत की है। एक और शिकायत पर आपका खाता 7 दिन के लिए बंद होगा।",
  },
  banned: {
    title: "Your UniShram account is paused / आपका खाता रोका गया है",
    body: "After a second report your account is paused for 7 days. Open the app to see why or to appeal. " +
      "दूसरी शिकायत के बाद आपका खाता 7 दिन के लिए रोका गया है। कारण देखने या अपील के लिए ऐप खोलें।",
  },
  suspended: {
    title: "Your UniShram account is suspended / आपका खाता निलंबित है",
    body: "After repeated reports your account is suspended until our team reviews it. You can appeal in the app. " +
      "बार-बार शिकायतों के बाद आपका खाता समीक्षा तक निलंबित है। आप ऐप में अपील कर सकते हैं।",
  },
};

/**
 * A user reported a job or a person. Stamps both sides' roles (from their
 * profiles, never from the client), closes a job that several people say is a
 * scam, and applies a strike when the report counts (see addStrike).
 */
exports.onReport = onDocumentCreated("reports/{reportId}", async (event) => {
  const report = event.data && event.data.data();
  if (!report) return;
  const reasons = reasonsOf(report);
  const aboutUserId = report.aboutUserId;
  console.warn("Report filed", {about: aboutUserId || report.jobId, reasons});

  const [by, about] = await Promise.all([
    db.collection("users").doc(report.byUserId).get(),
    aboutUserId ? db.collection("users").doc(aboutUserId).get() : null,
  ]);
  const stamp = {
    byRole: (by.exists && by.get("role")) || null,
    aboutRole: (about && about.exists && about.get("role")) || null,
  };

  if (report.jobId && reasons.some((r) => JOB_FRAUD_REASONS.includes(r))) {
    const jobReports = await db.collection("reports").where("jobId", "==", report.jobId).get();
    const reporters = new Set(jobReports.docs
        .filter((d) => reasonsOf(d.data()).some((r) => JOB_FRAUD_REASONS.includes(r)))
        .map((d) => d.get("byUserId")));
    if (reporters.size >= JOB_FRAUD_CLOSE_THRESHOLD) {
      await holdJob(db.collection("jobs").doc(report.jobId), "reported_fraud");
      console.warn("Job closed after fraud reports", {jobId: report.jobId, reporters: reporters.size});
    }
  }

  // Why a report did or didn't count is recorded on it for moderators.
  let strike = "no_subject";
  if (aboutUserId && about && about.exists) {
    if (by.exists && by.get("suspended") === true) {
      strike = "reporter_suspended";
    } else if (!(await haveDealtWith(report.byUserId, aboutUserId))) {
      strike = "no_connection";
    } else {
      const outcome = await addStrike(aboutUserId, report.byUserId, event.params.reportId, reasons);
      strike = outcome ? outcome.status : "repeat_reporter";
      if (outcome) {
        if (outcome.status !== "warned") await holdOpenJobsOf(aboutUserId, "poster_" + outcome.status);
        console.warn("Strike applied", {uid: aboutUserId, strikes: outcome.count, status: outcome.status});
        try {
          await notify(aboutUserId, MODERATION_PUSH[outcome.status], {type: "moderation", status: outcome.status});
        } catch (e) {
          console.error("Moderation push failed", e);
        }
      }
    }
  }
  await event.data.ref.set({...stamp, strike}, {merge: true});
});

/** Ends a temporary ban whose time is up. A permanent suspension is left alone. */
async function liftBanIfExpired(uid) {
  const lifted = await db.runTransaction(async (tx) => {
    const ledgerRef = moderationLedger(uid);
    const ledger = await tx.get(ledgerRef);
    if (!ledger.exists || ledger.get("status") !== "banned") return false;
    const until = ledger.get("bannedUntil");
    if (!until || until.toMillis() > Date.now()) return false;
    tx.set(ledgerRef, {status: "warned", bannedUntil: null, updatedAt: FieldValue.serverTimestamp()}, {merge: true});
    tx.set(moderationView(uid), {
      status: "warned", bannedUntil: null, updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    tx.set(db.collection("users").doc(uid), {suspended: false}, {merge: true});
    return true;
  });
  if (lifted) {
    // Jobs closed by the ban may be reopened by their poster again.
    const jobs = await db.collection("jobs").where("postedBy", "==", uid).get();
    await Promise.all(jobs.docs
        .filter((d) => d.get("moderationHold") === "poster_banned")
        .map((d) => d.ref.update({moderationHold: FieldValue.delete()})));
    console.warn("Temporary ban ended", {uid});
  }
  return lifted;
}

exports.liftExpiredBans = onSchedule("every 60 minutes", async () => {
  // Single-field range query; status is checked inside liftBanIfExpired.
  const due = await db.collection("moderationLedger")
      .where("bannedUntil", "<=", Timestamp.now()).get();
  for (const d of due.docs) await liftBanIfExpired(d.id);
});

/** The app's "check again" on the pause screen: lifts the caller's ban if it is over. */
exports.refreshMyStanding = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in first.");
  const lifted = await liftBanIfExpired(request.auth.uid);
  const view = await moderationView(request.auth.uid).get();
  return {lifted, status: (view.exists && view.get("status")) || "clear"};
});

/** An appeal marks the person's notice as under review until a moderator answers. */
exports.onAppeal = onDocumentCreated("appeals/{appealId}", async (event) => {
  const appeal = event.data && event.data.data();
  if (!appeal || !appeal.byUserId) return;
  await moderationView(appeal.byUserId).set(
      {appealPendingAt: FieldValue.serverTimestamp()}, {merge: true});
  console.warn("Appeal filed", {uid: appeal.byUserId, appealId: event.params.appealId});
});

// Import migration functions
const migration = require('./migrate_contractor_phone');
exports.migrateContractorPhone = migration.migrateContractorPhone;
exports.verifyMigration = migration.verifyMigration;
exports.postJob = require("./post_job").postJob;
exports.cleanupContractorPhone = migration.cleanupContractorPhone;

/**
 * Proxies India Post's free PIN-code directory server-side. India Post's API
 * sends no CORS headers, so Flutter web calling it directly gets silently
 * blocked by the browser; this function calls it from the server (where CORS
 * doesn't apply) and adds its own CORS header so the Flutter app — web or
 * native — can call this instead.
 */
exports.lookupPincode = onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  const pincode = `${req.query.pincode || ""}`.trim();
  if (!/^\d{6}$/.test(pincode)) {
    res.status(400).json({error: "invalid pincode"});
    return;
  }
  try {
    const upstream = await fetch(`https://api.postalpincode.in/pincode/${pincode}`);
    if (!upstream.ok) {
      res.status(502).json({error: "upstream error"});
      return;
    }
    const data = await upstream.json();
    const entry = Array.isArray(data) ? data[0] : null;
    if (!entry || entry.Status !== "Success" || !Array.isArray(entry.PostOffice) || entry.PostOffice.length === 0) {
      res.status(404).json({error: "not found"});
      return;
    }
    const office = entry.PostOffice[0];
    res.json({
      name: office.Name || "",
      district: office.District || "",
      state: office.State || "",
    });
  } catch (e) {
    res.status(502).json({error: "lookup failed"});
  }
});

/** Clean up contractor contact when job is deleted */
exports.onJobDeleted = onDocumentDeleted("jobs/{jobId}", async (event) => {
  try {
    await db.collection("contractorContacts").doc(event.params.jobId).delete();
  } catch (e) {
    console.error("Failed to delete contractor contact", e);
  }
});

/** Closes jobs whose end date has passed, so the feed stays current. */
exports.closeExpiredJobs = onSchedule("every day 02:00", async () => {
  const now = Timestamp.now();
  const snap = await db.collection("jobs")
      .where("status", "==", "open")
      .where("endDate", "<", now)
      .limit(500)
      .get();
  await Promise.all(snap.docs.map((d) => d.ref.update({status: "closed"})));
});
