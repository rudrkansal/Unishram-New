#!/usr/bin/env node
/**
 * READ-ONLY integrity audit. Performs only .get()/query reads — no writes, no deletes.
 * Prints counts and document ids only; never prints phone numbers or other field values.
 *
 *   emulator:    FIRESTORE_EMULATOR_HOST=127.0.0.1:PORT GCLOUD_PROJECT=demo-x node scripts/audit_integrity_readonly.js
 *   real project: GOOGLE_APPLICATION_CREDENTIALS=<path> GCLOUD_PROJECT=<id> node scripts/audit_integrity_readonly.js --allow-production
 */
const path = require("path");
const admin = require(path.join(__dirname, "..", "functions", "node_modules", "firebase-admin"));
if (!process.env.FIRESTORE_EMULATOR_HOST && !process.argv.includes("--allow-production")) {
  console.error("Refusing to read a real project without --allow-production."); process.exit(2);
}
admin.initializeApp({projectId: process.env.GCLOUD_PROJECT || undefined});
const db = admin.firestore();
const LIVE = ["pending", "shortlisted", "hired"];

async function all(col, fn) {
  let last = null, n = 0;
  for (;;) {
    let q = db.collection(col).orderBy("__name__").limit(300);
    if (last) q = q.startAfter(last);
    const s = await q.get(); if (s.empty) break;
    for (const d of s.docs) { last = d; n++; await fn(d); }
  }
  return n;
}

(async () => {
  const jobs = new Map(); // id -> {postedBy, hasContractorPhoneField}
  const r = {
    jobs: {scanned: 0, withContractorPhoneField: 0, withNonEmptyContractorPhone: 0, ids: []},
    applications: {scanned: 0, missingJob: [], contractorMismatch: [], missingContractorId: []},
    threads: {scanned: 0, noJobId: [], jobMissing: [], badParticipantShape: [], notPosterPlusApplicant: [], applicationNotLive: []},
    users: {scanned: 0, withPublicPhone: 0, withPrivatePhone: 0, publicOnly: 0, conflict: 0, privateOnly: 0},
  };
  r.jobs.scanned = await all("jobs", (d) => {
    const x = d.data(); jobs.set(d.id, {postedBy: x.postedBy});
    if ("contractorPhone" in x) { r.jobs.withContractorPhoneField++; if (x.contractorPhone) { r.jobs.withNonEmptyContractorPhone++; r.jobs.ids.push(d.id); } }
  });
  const apps = new Map();
  r.applications.scanned = await all("applications", (d) => {
    const x = d.data(); apps.set(d.id, x.status);
    const job = jobs.get(x.jobId);
    if (!job) r.applications.missingJob.push(d.id);
    else if (x.contractorId === undefined || x.contractorId === "") r.applications.missingContractorId.push(d.id);
    else if (x.contractorId !== job.postedBy) r.applications.contractorMismatch.push(d.id);
  });
  r.threads.scanned = await all("threads", (d) => {
    const x = d.data(); const p = x.participants;
    if (!Array.isArray(p) || p.length !== 2 || p[0] === p[1]) { r.threads.badParticipantShape.push(d.id); return; }
    if (typeof x.jobId !== "string" || !x.jobId) { r.threads.noJobId.push(d.id); return; }
    const job = jobs.get(x.jobId);
    if (!job) { r.threads.jobMissing.push(d.id); return; }
    const other = p.find((u) => u !== job.postedBy);
    if (!p.includes(job.postedBy) || p.filter((u) => u === job.postedBy).length !== 1) { r.threads.notPosterPlusApplicant.push(d.id); return; }
    if (!apps.has(`${x.jobId}_${other}`)) r.threads.notPosterPlusApplicant.push(d.id);
    else if (!LIVE.includes(apps.get(`${x.jobId}_${other}`))) r.threads.applicationNotLive.push(d.id); // informational: history of a withdrawn/rejected application
  });
  r.users.scanned = await all("users", async (d) => {
    const pub = typeof d.get("phone") === "string" && d.get("phone") !== "";
    const priv = await d.ref.collection("private").doc("contact").get();
    const pv = priv.exists ? priv.get("phone") : null;
    if (pub) r.users.withPublicPhone++;
    if (pv) r.users.withPrivatePhone++;
    if (pub && !pv) r.users.publicOnly++;
    if (!pub && pv) r.users.privateOnly++;
    if (pub && pv && pv !== d.get("phone")) r.users.conflict++;
  });
  const cap = (a) => ({count: a.length, ids: a.slice(0, 50)});
  console.log(JSON.stringify({
    jobs: {scanned: r.jobs.scanned, withContractorPhoneField: r.jobs.withContractorPhoneField, withNonEmptyContractorPhone: r.jobs.withNonEmptyContractorPhone, ids: r.jobs.ids.slice(0, 50)},
    applications: {scanned: r.applications.scanned, missingJob: cap(r.applications.missingJob), contractorMismatch: cap(r.applications.contractorMismatch), missingContractorId: cap(r.applications.missingContractorId)},
    threads: {scanned: r.threads.scanned, badParticipantShape: cap(r.threads.badParticipantShape), noJobId: cap(r.threads.noJobId), jobMissing: cap(r.threads.jobMissing), notPosterPlusApplicant: cap(r.threads.notPosterPlusApplicant), applicationNotLive_informational: cap(r.threads.applicationNotLive)},
    users: r.users,
  }, null, 2));
})().catch((e) => { console.error(e.message); process.exit(1); });
