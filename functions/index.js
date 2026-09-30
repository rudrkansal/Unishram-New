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
  await jobRef.update({applicantCount: admin.firestore.FieldValue.increment(1)});

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
  const now = admin.firestore.Timestamp.now();
  const oneMinuteAgo = admin.firestore.Timestamp.fromMillis(now.toMillis() - 60000);
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
const MIN_WAGE = {
  "Andaman & Nicobar Islands": {unskilled: 660, semi_skilled: 726, skilled: 792},
  "Andhra Pradesh": {unskilled: 430, semi_skilled: 474, skilled: 522},
  "Arunachal Pradesh": {unskilled: 394, semi_skilled: 435, skilled: 480},
  "Assam": {unskilled: 406, semi_skilled: 449, skilled: 493},
  "Bihar": {unskilled: 331, semi_skilled: 365, skilled: 403},
  "Chandigarh": {unskilled: 401, semi_skilled: 442, skilled: 487},
  "Chhattisgarh": {unskilled: 340, semi_skilled: 375, skilled: 414},
  "Delhi": {unskilled: 783, semi_skilled: 863, skilled: 949},
  "Goa": {unskilled: 412, semi_skilled: 454, skilled: 500},
  "Gujarat": {unskilled: 324, semi_skilled: 357, skilled: 393},
  "Haryana": {unskilled: 585, semi_skilled: 644, skilled: 708},
  "Himachal Pradesh": {unskilled: 370, semi_skilled: 408, skilled: 449},
  "Jammu & Kashmir": {unskilled: 371, semi_skilled: 409, skilled: 450},
  "Jharkhand": {unskilled: 515, semi_skilled: 567, skilled: 624},
  "Karnataka": {unskilled: 560, semi_skilled: 619, skilled: 681},
  "Kerala": {unskilled: 737, semi_skilled: 811, skilled: 893},
  "Ladakh": {unskilled: 450, semi_skilled: 450, skilled: 450},
  "Lakshadweep": {unskilled: 565, semi_skilled: 623, skilled: 687},
  "Madhya Pradesh": {unskilled: 335, semi_skilled: 369, skilled: 407},
  "Maharashtra": {unskilled: 595, semi_skilled: 654, skilled: 720},
  "Manipur": {unskilled: 364, semi_skilled: 401, skilled: 443},
  "Meghalaya": {unskilled: 555, semi_skilled: 611, skilled: 672},
  "Mizoram": {unskilled: 389, semi_skilled: 429, skilled: 474},
  "Nagaland": {unskilled: 360, semi_skilled: 396, skilled: 437},
  "Odisha": {unskilled: 472, semi_skilled: 520, skilled: 572},
  "Puducherry": {unskilled: 433, semi_skilled: 478, skilled: 528},
  "Punjab": {unskilled: 519, semi_skilled: 553, skilled: 593},
  "Rajasthan": {unskilled: 259, semi_skilled: 272, skilled: 284},
  "Sikkim": {unskilled: 412, semi_skilled: 454, skilled: 501},
  "Tamil Nadu": {unskilled: 450, semi_skilled: 500, skilled: 560},
  "Telangana": {unskilled: 615, semi_skilled: 677, skilled: 746},
  "Tripura": {unskilled: 410, semi_skilled: 451, skilled: 497},
  "Uttar Pradesh": {unskilled: 435, semi_skilled: 479, skilled: 527},
  "Uttarakhand": {unskilled: 361, semi_skilled: 398, skilled: 438},
  "West Bengal": {unskilled: 406, semi_skilled: 447, skilled: 492},
};
const DEFAULT_MIN_WAGE = {unskilled: 400, semi_skilled: 450, skilled: 500};
const UNSKILLED = ["Helper", "Earthwork Worker"];
const SEMI_SKILLED = ["Waterproofing Worker", "Scaffolding Worker", "Road Worker",
  "Paving Worker", "Drainage Worker"];

function categoryFor(skill) {
  if (UNSKILLED.includes(skill)) return "unskilled";
  if (SEMI_SKILLED.includes(skill)) return "semi_skilled";
  return "skilled";
}

exports.onJobPosted = onDocumentCreated("jobs/{jobId}", async (event) => {
  const job = event.data && event.data.data();
  if (!job) return;

  const row = MIN_WAGE[job.state] || DEFAULT_MIN_WAGE;
  const minimum = row[categoryFor(job.skill)] || row.skilled;

  await event.data.ref.update({
    minWageAtPost: minimum,
    belowMinimumWage: Number(job.wage) < minimum,
  });

  // Store contractor contact info in restricted collection (privacy protection)
  if (job.postedBy) {
    const contractorDoc = await db.collection("users").doc(job.postedBy).get();
    const contractorData = contractorDoc.data() || {};
    await db.collection("contractorContacts").doc(event.params.jobId).set({
      contractorId: job.postedBy,
      contractorName: job.contractorName || contractorData.fullName || '',
      contractorPhone: contractorData.phone || '',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  // Starts the cooldown the `jobs` create rule enforces (see
  // `notRateLimited()` in firestore.rules) — stamped here, not by the
  // client, so there is nothing for a client to forge.
  if (job.postedBy) {
    await db.collection("users").doc(job.postedBy).set(
        {lastJobPostedAt: admin.firestore.FieldValue.serverTimestamp()},
        {merge: true},
    );
  }
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
 * Account deletion, as required by both stores. Removes the profile, jobs,
 * applications, listings, photos and finally the auth user.
 */
exports.deleteAccount = onCall(async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in first.");

  const batchDelete = async (query) => {
    const snap = await query.get();
    await Promise.all(snap.docs.map((d) => d.ref.delete()));
  };

  await batchDelete(db.collection("jobs").where("postedBy", "==", uid));
  await batchDelete(db.collection("applications").where("workerId", "==", uid));
  await batchDelete(db.collection("listings").where("vendorId", "==", uid));
  await batchDelete(db.collection("users").doc(uid).collection("tokens"));
  await batchDelete(db.collection("users").doc(uid).collection("private"));

  try {
    await admin.storage().bucket().deleteFiles({prefix: `users/${uid}/`});
  } catch (e) {
    console.error("storage cleanup failed", e);
  }

  await db.collection("users").doc(uid).delete();
  await admin.auth().deleteUser(uid);

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
    {sessionRevoked: true, revokedAt: admin.firestore.FieldValue.serverTimestamp()},
    {merge: true}
  );

  return {ok: true};
});

// A person with this many reports against them in the window below is
// suspended automatically — pending a real moderator queue, this is the only
// thing standing between a reported user and continuing to use the app.
const REPORT_SUSPEND_THRESHOLD = 3;
const REPORT_WINDOW_DAYS = 30;

/** A user reported a job or a person: flag it, and auto-suspend on a pattern. */
exports.onReport = onDocumentCreated("reports/{reportId}", async (event) => {
  const report = event.data && event.data.data();
  if (!report) return;
  console.warn("Report filed", {
    about: report.aboutUserId || report.jobId,
    reason: report.reason,
  });

  const aboutUserId = report.aboutUserId;
  if (!aboutUserId) return;

  const cutoff = admin.firestore.Timestamp.fromMillis(
      Date.now() - REPORT_WINDOW_DAYS * 24 * 60 * 60 * 1000);
  const recent = await db.collection("reports")
      .where("aboutUserId", "==", aboutUserId)
      .where("createdAt", ">", cutoff)
      .count()
      .get();

  if (recent.data().count >= REPORT_SUSPEND_THRESHOLD) {
    await db.collection("users").doc(aboutUserId).set(
        {suspended: true}, {merge: true});
    console.warn("Auto-suspended after repeated reports", {
      uid: aboutUserId,
      count: recent.data().count,
    });
  }
});

// Import migration functions
const migration = require('./migrate_contractor_phone');
exports.migrateContractorPhone = migration.migrateContractorPhone;
exports.verifyMigration = migration.verifyMigration;
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
  const now = admin.firestore.Timestamp.now();
  const snap = await db.collection("jobs")
      .where("status", "==", "open")
      .where("endDate", "<", now)
      .limit(500)
      .get();
  await Promise.all(snap.docs.map((d) => d.ref.update({status: "closed"})));
});
