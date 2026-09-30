// Emulator-only security tests. Refuses to run unless the Auth/Firestore/
// Functions emulator env vars are present and the project id starts with
// "demo-", so it can never touch the deployed unishram-india project.
const {test, describe, before} = require("node:test");
const assert = require("node:assert/strict");
const {initializeApp} = require("firebase/app");
const {getAuth, connectAuthEmulator, createUserWithEmailAndPassword} = require("firebase/auth");
const {getFirestore, connectFirestoreEmulator, doc, setDoc, getDoc, getDocs, updateDoc, deleteDoc, collection,
  deleteField, serverTimestamp, Timestamp} = require("firebase/firestore");
const {getFunctions, connectFunctionsEmulator, httpsCallable} = require("firebase/functions");
const admin = require("firebase-admin");
const {execFileSync} = require("node:child_process");
const path = require("node:path");

const PROJECT = process.env.GCLOUD_PROJECT || "demo-unishram-test";
if (!PROJECT.startsWith("demo-") || !process.env.FIRESTORE_EMULATOR_HOST ||
    !process.env.FIREBASE_AUTH_EMULATOR_HOST) {
  throw new Error("Refusing to run: must be launched via `firebase emulators:exec` with a demo- project.");
}
const [fsHost, fsPort] = process.env.FIRESTORE_EMULATOR_HOST.split(":");
const [fnHost, fnPort] = (process.env.FUNCTIONS_EMULATOR_HOST || "127.0.0.1:15001").split(":");

admin.initializeApp({projectId: PROJECT});

const run = Date.now().toString(36);
const clients = {};

async function makeClient(name, {signIn = true} = {}) {
  const app = initializeApp({projectId: PROJECT, apiKey: "fake-key"}, `${name}-${run}`);
  const auth = getAuth(app);
  connectAuthEmulator(auth, `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}`, {disableWarnings: true});
  const db = getFirestore(app);
  connectFirestoreEmulator(db, fsHost, Number(fsPort));
  const functions = getFunctions(app, "asia-south1");
  connectFunctionsEmulator(functions, fnHost, Number(fnPort));
  let uid = null;
  if (signIn) {
    const cred = await createUserWithEmailAndPassword(auth, `${name}-${run}@test.invalid`, "T3st-only-pw!");
    uid = cred.user.uid;
  }
  return {app, auth, db, functions, uid};
}

async function code(promise) {
  try { await promise; return "ok"; } catch (e) { return e.code || String(e); }
}
const expectDenied = async (p) => assert.equal(await code(p), "permission-denied");
const expectOk = async (p) => assert.equal(await code(p), "ok");

// Jobs can only be created by the postJob Cloud Function (rules: `allow create: if false`).
const callCode = async (client, fn, data) => { try { await httpsCallable(client.functions, fn)(data); return "ok"; } catch (e) { return e.code || String(e); } };
const waitFor = async (fn, ms = 15000) => { const t = Date.now(); while (Date.now() - t < ms) { if (await fn()) return true; await new Promise((r) => setTimeout(r, 250)); } return false; };
const validJob = (extra = {}) => ({title: "Test job", description: "d", wage: 500, ...extra});
async function postJobOk(client, extra = {}) {
  const res = await httpsCallable(client.functions, "postJob")(validJob(extra));
  assert.ok(res.data.jobId, "postJob should return a jobId");
  return res.data.jobId;
}
// Test-fixture job created with the Admin SDK (as a server would). Still fires the real onJobPosted trigger.
const seedJob = (id, postedBy, extra = {}) => admin.firestore().doc(`jobs/${id}`).set({
  postedBy, title: "t", description: "d", wage: 500, status: "open", applicantCount: 0, ...extra});

let jobId, threadId;

before(async () => {
  for (const n of ["contractor", "worker", "stranger", "nonadmin", "admin", "withdrawn", "rejected", "shortlisted", "forger", "turnedDown", "newapp", "profile", "profile2", "poster", "rpost1", "rpost2", "phoneOwner", "phoneOther", "delUser", "delFull", "selfPoster", "selfApplicant", "cpA", "cpB", "pjNoUser", "pjSusp", "pjBurst", "pjIndepA", "pjIndepB", "pjVal", "pjGeo", "trigContractor", "trigW1", "trigW2", "trigOther"]) clients[n] = await makeClient(n);
  clients.anon = await makeClient("anon", {signIn: false});
  await admin.auth().setCustomUserClaims(clients.admin.uid, {admin: true});
  await clients.admin.auth.currentUser.getIdToken(true); // pick up the claim

  for (const n of ["contractor", "worker", "stranger"]) {
    await setDoc(doc(clients[n].db, "users", clients[n].uid), {
      role: n === "contractor" ? "contractor" : "labourer", fullName: `Test ${n}`,
    });
  }
  // Test job (contractor) and application (worker) through the real rules.
  jobId = `job-${run}`;
  await seedJob(jobId, clients.contractor.uid, {title: "Test job", description: "emulator only"});

  await setDoc(doc(clients.worker.db, "applications", `${jobId}_${clients.worker.uid}`), {
    jobId, workerId: clients.worker.uid, contractorId: clients.contractor.uid, status: "pending",
  });
  threadId = `thread-${run}`;

  // Extra applicants in different statuses, all against the same job.
  const apply = (n, extra = {}) => setDoc(doc(clients[n].db, "applications", `${jobId}_${clients[n].uid}`), {
    jobId, workerId: clients[n].uid, contractorId: clients.contractor.uid, status: "pending", ...extra,
  });
  for (const n of ["withdrawn", "rejected", "shortlisted"]) await apply(n);
  // Forged application: worker names the stranger as "contractor" (application create rule does not check this).
  const appDoc = (n, c) => doc(c.db, "applications", `${jobId}_${clients[n].uid}`);
  await updateDoc(appDoc("withdrawn", clients.withdrawn), {status: "withdrawn"});
  await updateDoc(appDoc("rejected", clients.contractor), {status: "rejected"});
  await updateDoc(appDoc("shortlisted", clients.contractor), {status: "shortlisted"});
});

const threadData = (participants, jid = jobId) => ({participants, jobId: jid, createdAt: Timestamp.now()});

describe("Firestore rules: threads", () => {
  test("1. thread IDOR create: stranger with no application, targets contractor+worker", async () => {
    const {stranger, contractor, worker} = clients;
    await expectDenied(setDoc(doc(stranger.db, "threads", `idor-${run}`),
      threadData([stranger.uid, worker.uid])));
    await expectDenied(setDoc(doc(stranger.db, "threads", `idor2-${run}`),
      threadData([stranger.uid, contractor.uid])));
  });

  test("1b. applicant -> unrelated user (not the job's poster) -> denied", async () => {
    const {worker, stranger} = clients;
    await expectDenied(setDoc(doc(worker.db, "threads", `idor3-${run}`),
      threadData([worker.uid, stranger.uid])));
  });

  test("1c. FORGED application.contractorId (stranger / self / missing / empty) -> create denied", async () => {
    const {forger, stranger} = clients;
    const ref = doc(forger.db, "applications", `${jobId}_${forger.uid}`);
    const base = {jobId, workerId: forger.uid, status: "pending"};
    await expectDenied(setDoc(ref, {...base, contractorId: stranger.uid}));
    await expectDenied(setDoc(ref, {...base, contractorId: forger.uid}));
    await expectDenied(setDoc(ref, {...base}));
    await expectDenied(setDoc(ref, {...base, contractorId: ""}));
    await expectDenied(setDoc(doc(forger.db, "applications", `nojob-${run}_${forger.uid}`),
      {...base, jobId: `nojob-${run}`, contractorId: stranger.uid}));
  });

  test("1c2. forged applicant then cannot open a thread with the stranger either -> denied", async () => {
    const {forger, stranger} = clients;
    await expectDenied(setDoc(doc(forger.db, "threads", `forge-${run}`),
      threadData([forger.uid, stranger.uid])));
  });

  test("1c3. application with the job's real contractorId -> create allowed", async () => {
    const {forger, contractor} = clients;
    await expectOk(setDoc(doc(forger.db, "applications", `${jobId}_${forger.uid}`),
      {jobId, workerId: forger.uid, status: "pending", contractorId: contractor.uid}));
  });

  test("1d. applicant -> contractor with a wrong/extra participant shape -> denied", async () => {
    const {worker, contractor, stranger} = clients;
    await expectDenied(setDoc(doc(worker.db, "threads", `shape1-${run}`),
      threadData([worker.uid, contractor.uid, stranger.uid])));
    await expectDenied(setDoc(doc(worker.db, "threads", `shape2-${run}`),
      threadData([contractor.uid, contractor.uid])));
    await expectDenied(setDoc(doc(worker.db, "threads", `shape3-${run}`),
      threadData([worker.uid, contractor.uid], "no-such-job")));
    await expectDenied(setDoc(doc(worker.db, "threads", `shape4-${run}`),
      {participants: [worker.uid, contractor.uid], createdAt: Timestamp.now()}));
  });

  test("1e. withdrawn applicant -> contractor -> denied", async () => {
    const {withdrawn, contractor} = clients;
    await expectDenied(setDoc(doc(withdrawn.db, "threads", `wd-${run}`),
      threadData([withdrawn.uid, contractor.uid])));
  });

  test("1f. rejected applicant -> contractor -> denied", async () => {
    const {rejected, contractor} = clients;
    await expectDenied(setDoc(doc(rejected.db, "threads", `rj-${run}`),
      threadData([rejected.uid, contractor.uid])));
  });

  test("1g. shortlisted applicant -> contractor -> allowed", async () => {
    const {shortlisted, contractor} = clients;
    await expectOk(setDoc(doc(shortlisted.db, "threads", `sl-${run}`),
      threadData([shortlisted.uid, contractor.uid])));
  });

  test("1h. contractor creating thread themselves (no application of their own) -> denied", async () => {
    const {worker, contractor} = clients;
    await expectDenied(setDoc(doc(contractor.db, "threads", `ct-${run}`),
      threadData([worker.uid, contractor.uid])));
  });

  test("2. legitimate thread create (worker with application + job's contractor)", async () => {
    const {worker, contractor} = clients;
    await expectOk(setDoc(doc(worker.db, "threads", threadId),
      threadData([worker.uid, contractor.uid])));
  });

  test("3. update participants -> denied", async () => {
    const {worker, contractor, stranger} = clients;
    await expectDenied(updateDoc(doc(worker.db, "threads", threadId),
      {participants: [worker.uid, stranger.uid]}));
    await expectDenied(updateDoc(doc(contractor.db, "threads", threadId),
      {participants: [contractor.uid, stranger.uid]}));
  });

  test("4. update jobId -> denied", async () => {
    await expectDenied(updateDoc(doc(clients.worker.db, "threads", threadId), {jobId: "other-job"}));
  });

  test("5. update createdAt -> denied", async () => {
    await expectDenied(updateDoc(doc(clients.worker.db, "threads", threadId),
      {createdAt: Timestamp.fromMillis(1)}));
  });

  test("3b/4b/5b. deleting participants / jobId / createdAt via deleteField -> denied", async () => {
    const {worker} = clients;
    for (const f of ["participants", "jobId", "createdAt"]) {
      await expectDenied(updateDoc(doc(worker.db, "threads", threadId), {[f]: deleteField()}));
    }
  });

  test("6. unrelated third user cannot read thread", async () => {
    await expectDenied(getDoc(doc(clients.stranger.db, "threads", threadId)));
  });

  test("7. participants can read and do allowed updates", async () => {
    const {worker, contractor} = clients;
    await expectOk(getDoc(doc(worker.db, "threads", threadId)));
    await expectOk(getDoc(doc(contractor.db, "threads", threadId)));
    await expectOk(updateDoc(doc(worker.db, "threads", threadId), {lastMessage: "hi", lastMessageAt: serverTimestamp()}));
    await expectOk(updateDoc(doc(contractor.db, "threads", threadId), {lastMessage: "hello"}));
    // The app's own pattern: merge-set with unchanged participants/jobId.
    await expectOk(setDoc(doc(worker.db, "threads", threadId),
      {participants: [worker.uid, contractor.uid], jobId, unread: {[worker.uid]: 0}}, {merge: true}));
  });
});

describe("Firestore rules: applications", () => {
  const appRef = (c, jid, uid) => doc(c.db, "applications", `${jid}_${uid}`);
  const body = (c, extra = {}) => ({jobId, workerId: c.uid, contractorId: clients.contractor.uid, status: "pending", ...extra});

  test("A1. correct contractorId -> allowed; legit flow (contractor shortlists/hires, worker withdraws) -> allowed", async () => {
    const {newapp, contractor} = clients;
    await expectOk(setDoc(appRef(newapp, jobId, newapp.uid), body(newapp)));
    await expectDenied(updateDoc(appRef(newapp, jobId, newapp.uid), {status: "shortlisted"})); // a worker cannot shortlist themselves
    await expectOk(updateDoc(appRef(contractor, jobId, newapp.uid), {status: "shortlisted"}));
    await expectOk(updateDoc(appRef(contractor, jobId, newapp.uid), {status: "hired"}));
    await expectOk(getDoc(appRef(newapp, jobId, newapp.uid)));
    await expectOk(getDoc(appRef(contractor, jobId, newapp.uid)));
  });
  test("A2. unrelated contractorId -> denied", async () => {
    const {stranger} = clients;
    const other = await makeClient("applicant-x");
    await expectDenied(setDoc(appRef(other, jobId, other.uid), body(other, {contractorId: stranger.uid})));
  });
  test("A3. nonexistent job -> denied", async () => {
    const other = await makeClient("applicant-y");
    await expectDenied(setDoc(appRef(other, "ghost-job", other.uid), body(other, {jobId: "ghost-job"})));
  });
  test("A4. unauthorized: signed-out create denied; creating for another worker's id denied; reading others' application denied", async () => {
    const {anon, stranger, worker} = clients;
    await expectDenied(setDoc(doc(anon.db, "applications", `${jobId}_someone`), {jobId, workerId: "someone", contractorId: clients.contractor.uid, status: "pending"}));
    await expectDenied(setDoc(appRef(stranger, jobId, worker.uid), {jobId, workerId: worker.uid, contractorId: clients.contractor.uid, status: "pending"}));
    await expectDenied(setDoc(appRef(stranger, jobId, stranger.uid), body(stranger, {status: "hired"})));
    await expectDenied(getDoc(appRef(stranger, jobId, worker.uid)));
    await expectDenied(deleteDoc(appRef(worker, jobId, worker.uid)));
  });
  test("A5. update: worker cannot self-hire, contractor cannot re-point contractorId, nobody can delete jobId/workerId/contractorId", async () => {
    const {worker, contractor, stranger} = clients;
    await expectDenied(updateDoc(appRef(worker, jobId, worker.uid), {status: "hired"}));
    await expectDenied(updateDoc(appRef(contractor, jobId, worker.uid), {contractorId: stranger.uid}));
    await expectDenied(updateDoc(appRef(stranger, jobId, worker.uid), {status: "rejected"}));
    for (const f of ["jobId", "workerId", "contractorId"]) {
      await expectDenied(updateDoc(appRef(contractor, jobId, worker.uid), {status: "pending", [f]: deleteField()}));
    }
    await expectDenied(updateDoc(appRef(worker, jobId, worker.uid), {status: "withdrawn", contractorId: deleteField()}));
  });
});

describe("Firestore rules: messages", () => {
  const msg = (c, text = "hello", extra = {}) => ({senderId: c.uid, text, ...extra});
  const mRef = (c, tid, id) => doc(c.db, "threads", tid, "messages", id);
  let mid;

  test("M1. participant creates message -> allowed; both participants read -> allowed", async () => {
    const {worker, contractor} = clients;
    mid = `m1-${run}`;
    await expectOk(setDoc(mRef(worker, threadId, mid), msg(worker)));
    await expectOk(setDoc(mRef(contractor, threadId, `m2-${run}`), msg(contractor, "reply")));
    await expectOk(getDoc(mRef(worker, threadId, mid)));
    await expectOk(getDoc(mRef(contractor, threadId, mid)));
    await expectOk(getDocs(collection(worker.db, "threads", threadId, "messages")));
  });
  test("M2. unauthorized user cannot read (get or list) messages, incl. signed-out", async () => {
    const {stranger, anon} = clients;
    await expectDenied(getDoc(mRef(stranger, threadId, mid)));
    await expectDenied(getDocs(collection(stranger.db, "threads", threadId, "messages")));
    await expectDenied(getDoc(mRef(anon, threadId, mid)));
    await expectDenied(getDocs(collection(anon.db, "threads", threadId, "messages")));
  });
  test("M3. unauthorized user cannot create, even knowing the thread id or spoofing senderId", async () => {
    const {stranger, anon, worker, contractor} = clients;
    await expectDenied(setDoc(mRef(stranger, threadId, `x1-${run}`), msg(stranger)));
    await expectDenied(setDoc(mRef(stranger, threadId, `x2-${run}`), msg(worker)));
    await expectDenied(setDoc(mRef(stranger, threadId, `x3-${run}`), msg(contractor)));
    await expectDenied(setDoc(mRef(anon, threadId, `x4-${run}`), {senderId: worker.uid, text: "hi"}));
  });
  test("M3b. participant cannot impersonate the other participant", async () => {
    const {worker, contractor} = clients;
    await expectDenied(setDoc(mRef(worker, threadId, `imp-${run}`), msg(contractor)));
  });
  test("M4. unauthorized and even participants cannot update or delete messages", async () => {
    const {stranger, worker, contractor} = clients;
    for (const c of [stranger, worker, contractor]) {
      await expectDenied(updateDoc(mRef(c, threadId, mid), {text: "edited"}));
      await expectDenied(deleteDoc(mRef(c, threadId, mid)));
    }
  });
  test("M5. create validation: empty / oversize / non-string text, and nonexistent thread -> denied", async () => {
    const {worker} = clients;
    await expectDenied(setDoc(mRef(worker, threadId, `v1-${run}`), msg(worker, "")));
    await expectDenied(setDoc(mRef(worker, threadId, `v2-${run}`), msg(worker, "x".repeat(2001))));
    await expectDenied(setDoc(mRef(worker, threadId, `v3-${run}`), msg(worker, 123)));
    await expectDenied(setDoc(mRef(worker, threadId, `v4-${run}`), {senderId: worker.uid}));
    await expectDenied(setDoc(mRef(worker, `no-such-thread-${run}`, `v5-${run}`), msg(worker)));
  });
  test("M6. blocked sender cannot message; unblocking restores", async () => {
    const {shortlisted, contractor} = clients;
    const tid = `sl-${run}`;
    await expectOk(setDoc(mRef(shortlisted, tid, `b0-${run}`), msg(shortlisted)));
    const blockRef = doc(contractor.db, "users", contractor.uid, "blocks", shortlisted.uid);
    await setDoc(blockRef, {at: Timestamp.now()});
    await expectDenied(setDoc(mRef(shortlisted, tid, `b1-${run}`), msg(shortlisted)));
    await expectOk(setDoc(mRef(contractor, tid, `b2-${run}`), msg(contractor)));
    await deleteDoc(blockRef);
    await expectOk(setDoc(mRef(shortlisted, tid, `b3-${run}`), msg(shortlisted)));
  });
  test("M7. rejected application: thread history readable, new messages denied from both sides; deleting jobId cannot bypass", async () => {
    const {turnedDown, contractor} = clients;
    await setDoc(appRef2(turnedDown), {jobId, workerId: turnedDown.uid, contractorId: contractor.uid, status: "pending"});
    const tid = `td-${run}`;
    await expectOk(setDoc(doc(turnedDown.db, "threads", tid), threadData([turnedDown.uid, contractor.uid])));
    await expectOk(setDoc(mRef(turnedDown, tid, `r0-${run}`), msg(turnedDown)));
    await updateDoc(appRef2(contractor, turnedDown.uid), {status: "rejected"});
    await expectDenied(setDoc(mRef(turnedDown, tid, `r1-${run}`), msg(turnedDown)));
    await expectDenied(setDoc(mRef(contractor, tid, `r2-${run}`), msg(contractor)));
    await expectOk(getDoc(mRef(turnedDown, tid, `r0-${run}`)));
    // bypass attempts: drop / swap jobId, replace participants
    await expectDenied(updateDoc(doc(turnedDown.db, "threads", tid), {jobId: deleteField()}));
    await expectDenied(updateDoc(doc(turnedDown.db, "threads", tid), {jobId: "other"}));
    await expectDenied(setDoc(mRef(turnedDown, tid, `r3-${run}`), msg(turnedDown)));
    // and a fresh thread can't be opened for the rejected application
    await expectDenied(setDoc(doc(turnedDown.db, "threads", `td2-${run}`), threadData([turnedDown.uid, contractor.uid])));
  });
  function appRef2(c, uid) { return doc(c.db, "applications", `${jobId}_${uid || c.uid}`); }
});

describe("Firestore rules: users / jobs protected-field regression", () => {
  const uRef = (c) => doc(c.db, "users", c.uid);
  before(async () => {
    // Server-owned flags are written by the Admin SDK (emulator), as the real Cloud Functions do.
    for (const n of ["profile", "profile2"]) {
      await setDoc(uRef(clients[n]), {role: "labourer", fullName: `Test ${n}`});
    }
    await admin.firestore().doc(`users/${clients.profile.uid}`).update({suspended: true, ratingAverage: 4, ratingCount: 3});
    await admin.firestore().doc(`users/${clients.profile2.uid}`).update({suspended: false, ratingAverage: 4, ratingCount: 3});
    for (const [j, n] of [["pj-del", "rpost1"], ["pj-edit", "rpost2"]]) {
      await setDoc(doc(clients[n].db, "users", clients[n].uid), {role: "contractor", fullName: n});
      await seedJob(`${j}-${run}`, clients[n].uid);
    }
  });

  for (const [i, f] of [[1, "suspended"], [2, "role"], [3, "ratingAverage"], [4, "ratingCount"]]) {
    test(`R${i}. users.${f} deletion -> denied`, async () => {
      await expectDenied(updateDoc(uRef(clients.profile), {[f]: deleteField()}));
    });
  }
  test("R1b. users protected fields cannot be changed either (value edits) -> denied", async () => {
    const c = clients.profile;
    await expectDenied(updateDoc(uRef(c), {suspended: false}));
    await expectDenied(updateDoc(uRef(c), {role: "contractor"}));
    await expectDenied(updateDoc(uRef(c), {ratingAverage: 5}));
    await expectDenied(updateDoc(uRef(c), {ratingCount: 99}));
    await expectDenied(updateDoc(uRef(c), {fullName: "ok", suspended: deleteField()})); // bundled with a legit edit
  });
  test("R5. jobs.postedBy deletion -> denied; change -> denied", async () => {
    const contractor = clients.rpost1, {stranger} = clients;
    await expectDenied(updateDoc(doc(contractor.db, "jobs", `pj-del-${run}`), {postedBy: deleteField()}));
    await expectDenied(updateDoc(doc(contractor.db, "jobs", `pj-del-${run}`), {postedBy: stranger.uid}));
    await expectDenied(updateDoc(doc(stranger.db, "jobs", `pj-del-${run}`), {title: "hijack"}));
  });
  test("R6. legitimate user profile updates -> allowed (incl. app-style merge set, with protected fields unchanged)", async () => {
    const c = clients.profile2;
    await expectOk(updateDoc(uRef(c), {fullName: "New Name", city: "Pune"}));
    await expectOk(setDoc(uRef(c), {fullName: "Merged Name", language: "hi"}, {merge: true}));
    await expectOk(setDoc(uRef(c), {role: "labourer", suspended: false, ratingAverage: 4, ratingCount: 3, fullName: "Same"}, {merge: true}));
  });
  test("R7. legitimate job edits by the poster -> allowed", async () => {
    const contractor = clients.rpost2;
    const r = doc(contractor.db, "jobs", `pj-edit-${run}`);
    await expectOk(updateDoc(r, {title: "Edited title", wage: 600}));
    await expectOk(updateDoc(r, {status: "closed"}));
    await expectOk(setDoc(r, {description: "merged edit"}, {merge: true}));
  });
});

describe("Firestore rules: applicantCount / lastJobPostedAt regression + rate limit", () => {
  let ratedJob;

  before(async () => {
    await setDoc(doc(clients.poster.db, "users", clients.poster.uid), {role: "contractor", fullName: "Poster"});
    // First post goes through the real callable; it stamps lastJobPostedAt atomically with the job.
    ratedJob = await postJobOk(clients.poster);
    const stamped = (await admin.firestore().doc(`users/${clients.poster.uid}`).get()).get("lastJobPostedAt");
    assert.ok(stamped, "postJob should have stamped lastJobPostedAt in the same transaction");
  });

  test("L1. jobs.applicantCount deletion -> denied", async () => {
    await expectDenied(updateDoc(doc(clients.poster.db, "jobs", ratedJob), {applicantCount: deleteField()}));
    await expectDenied(updateDoc(doc(clients.poster.db, "jobs", ratedJob), {title: "x", applicantCount: deleteField()}));
  });
  test("L2. jobs.applicantCount modification -> denied", async () => {
    await expectDenied(updateDoc(doc(clients.poster.db, "jobs", ratedJob), {applicantCount: 50}));
    await expectDenied(updateDoc(doc(clients.poster.db, "jobs", ratedJob), {applicantCount: -1}));
  });
  test("L3. legit job edit with applicantCount untouched / unchanged -> allowed (also after the real onApplication bump)", async () => {
    const r = doc(clients.poster.db, "jobs", ratedJob);
    await expectOk(updateDoc(r, {title: "Edited", wage: 700}));
    await expectOk(updateDoc(r, {applicantCount: 0, description: "same count resent"}));
    // Real server-side path: a real application fires onApplication, which bumps the count; a client edit resending it is fine.
    const w = clients.newapp;
    await setDoc(doc(w.db, "applications", `${ratedJob}_${w.uid}`), {jobId: ratedJob, workerId: w.uid, contractorId: clients.poster.uid, status: "pending"});
    assert.ok(await waitFor(async () => (await admin.firestore().doc(`jobs/${ratedJob}`).get()).get("applicantCount") === 1), "applicantCount should be incremented by onApplication");
    await expectOk(updateDoc(r, {applicantCount: 1, title: "After server bump"}));
    await expectDenied(updateDoc(r, {applicantCount: 0}));
  });
  test("L4. users.lastJobPostedAt deletion -> denied", async () => {
    await expectDenied(updateDoc(doc(clients.poster.db, "users", clients.poster.uid), {lastJobPostedAt: deleteField()}));
    await expectDenied(updateDoc(doc(clients.poster.db, "users", clients.poster.uid), {fullName: "Y", lastJobPostedAt: deleteField()}));
  });
  test("L5. users.lastJobPostedAt modification -> denied", async () => {
    const u = doc(clients.poster.db, "users", clients.poster.uid);
    await expectDenied(updateDoc(u, {lastJobPostedAt: Timestamp.fromMillis(1)}));
    await expectDenied(updateDoc(u, {lastJobPostedAt: serverTimestamp()}));
  });
  test("L6. legit profile edit with lastJobPostedAt unchanged -> allowed", async () => {
    const u = doc(clients.poster.db, "users", clients.poster.uid);
    await expectOk(updateDoc(u, {fullName: "Poster Renamed", city: "Delhi"}));
    await expectOk(setDoc(u, {language: "hi"}, {merge: true}));
  });
  test("L7. rate limit: 2nd post refused; client cannot bypass by direct create or by touching the stamp; server clock elapse -> allowed", async () => {
    const c = clients.poster;
    assert.equal(await callCode(c, "postJob", validJob()), "functions/resource-exhausted");
    await expectDenied(setDoc(doc(c.db, "jobs", `rl2-${run}`), {postedBy: c.uid, title: "t", description: "d", wage: 500, status: "open", applicantCount: 0}));
    await expectDenied(updateDoc(doc(c.db, "users", c.uid), {lastJobPostedAt: deleteField()}));
    assert.equal(await callCode(c, "postJob", validJob()), "functions/resource-exhausted");
    // Simulate the 15s cooldown elapsing by back-dating the stamp (Admin SDK) -> allowed again
    await admin.firestore().doc(`users/${c.uid}`).update({lastJobPostedAt: new Date(Date.now() - 60000)});
    assert.equal(await callCode(c, "postJob", validJob()), "ok");
  });
});

// These exercise the ACTUAL onJobPosted / onApplication Cloud Functions running in the Functions emulator.
// The Admin SDK is used here only to OBSERVE results (reads), never to perform the trigger's writes.
describe("Cloud Function triggers (real): onJobPosted / onApplication", () => {
  const PHONE = "+919876500001";
  const poll = async (fn, ms = 20000) => { const t = Date.now(); let v; while (Date.now() - t < ms) { v = await fn(); if (v) return v; await new Promise((r) => setTimeout(r, 300)); } return v; };
  const adb = () => admin.firestore();
  let tj;

  before(async () => {
    const c = clients.trigContractor;
    // Phone is stored where the app stores it: the owner-only private doc, NOT the public profile.
    await setDoc(doc(c.db, "users", c.uid), {role: "contractor", fullName: "Trig Contractor"});
    await setDoc(doc(c.db, "users", c.uid, "private", "contact"), {phone: PHONE});
  });

  test("T1. postJob + real onJobPosted: job created; wage flags written by the trigger; lastJobPostedAt stamped by the callable", async () => {
    const c = clients.trigContractor;
    tj = await postJobOk(c, {title: "Trigger job", wage: 100, state: "Maharashtra", skill: "Helper"});
    const job = await poll(async () => { const d = await adb().doc(`jobs/${tj}`).get(); return d.get("minWageAtPost") !== undefined ? d : null; });
    assert.ok(job, "onJobPosted should set minWageAtPost");
    assert.equal(job.get("belowMinimumWage"), true);
    const user = await adb().doc(`users/${c.uid}`).get();
    assert.ok(user.get("lastJobPostedAt"), "postJob should have stamped users/{uid}.lastJobPostedAt");
  });

  test("T2. onJobPosted: contractorContacts/{jobId} created with the phone, and the public job doc exposes no phone", async () => {
    const c = clients.trigContractor;
    const cc = await poll(async () => { const d = await adb().doc(`contractorContacts/${tj}`).get(); return d.exists ? d : null; });
    assert.ok(cc, "contractorContacts doc should exist");
    assert.equal(cc.get("contractorId"), c.uid);
    assert.equal(cc.get("contractorPhone"), PHONE, "function must copy the phone from users/{uid}/private/contact");
    assert.ok(cc.get("createdAt"), "createdAt should be a server timestamp");
    const job = (await adb().doc(`jobs/${tj}`).get()).data();
    assert.equal(Object.keys(job).some((k) => /phone/i.test(k)), false, "job doc must have no phone field");
    assert.equal(JSON.stringify(job).includes(PHONE), false, "job doc must not contain the phone number");
    const profile = (await adb().doc(`users/${c.uid}`).get()).data();
    assert.equal("phone" in profile, false, "public profile must not contain a phone");
  });

  test("T3. contractorContacts privacy via rules: contractor reads; stranger denied; nobody writes", async () => {
    const {trigContractor: c, trigOther} = clients;
    await expectOk(getDoc(doc(c.db, "contractorContacts", tj)));
    await expectDenied(getDoc(doc(trigOther.db, "contractorContacts", tj)));
    await expectDenied(setDoc(doc(c.db, "contractorContacts", tj), {contractorPhone: "x"}));
    await expectDenied(setDoc(doc(trigOther.db, "contractorContacts", `new-${run}`), {contractorId: trigOther.uid}));
  });

  test("T4. the callable's stamp is live: immediate second post is refused", async () => {
    assert.equal(await callCode(clients.trigContractor, "postJob", validJob()), "functions/resource-exhausted");
  });

  test("T5. onApplication: valid applications create; applicantCount increments 0 -> 1 -> 2", async () => {
    const {trigW1, trigW2, trigContractor: c} = clients;
    const app = (w) => ({jobId: tj, workerId: w.uid, contractorId: c.uid, status: "pending", workerName: "W"});
    await expectOk(setDoc(doc(trigW1.db, "applications", `${tj}_${trigW1.uid}`), app(trigW1)));
    assert.ok(await poll(async () => (await adb().doc(`jobs/${tj}`).get()).get("applicantCount") === 1), "count should reach 1");
    await expectOk(setDoc(doc(trigW2.db, "applications", `${tj}_${trigW2.uid}`), app(trigW2)));
    assert.ok(await poll(async () => (await adb().doc(`jobs/${tj}`).get()).get("applicantCount") === 2), "count should reach 2");
  });

  test("T6. onApplication: invalid / unauthorized applications are rejected and the count does not move", async () => {
    const {trigW1, trigOther, trigContractor: c} = clients;
    const count = async () => (await adb().doc(`jobs/${tj}`).get()).get("applicantCount");
    // duplicate re-apply by same worker, forged contractorId, spoofed workerId, nonexistent job, signed-out
    await expectDenied(setDoc(doc(trigW1.db, "applications", `${tj}_${trigW1.uid}`), {jobId: tj, workerId: trigW1.uid, contractorId: c.uid, status: "pending"}));
    await expectDenied(setDoc(doc(trigOther.db, "applications", `${tj}_${trigOther.uid}`), {jobId: tj, workerId: trigOther.uid, contractorId: trigOther.uid, status: "pending"}));
    await expectDenied(setDoc(doc(trigOther.db, "applications", `${tj}_${trigW1.uid}x`), {jobId: tj, workerId: trigW1.uid, contractorId: c.uid, status: "pending"}));
    await expectDenied(setDoc(doc(trigOther.db, "applications", `ghost-${run}_${trigOther.uid}`), {jobId: `ghost-${run}`, workerId: trigOther.uid, contractorId: c.uid, status: "pending"}));
    await expectDenied(setDoc(doc(clients.anon.db, "applications", `${tj}_anon`), {jobId: tj, workerId: "anon", contractorId: c.uid, status: "pending"}));
    await new Promise((r) => setTimeout(r, 2500)); // give any (wrongly) fired trigger time to act
    assert.equal(await count(), 2);
    // clients cannot bump / delete the counter themselves
    await expectDenied(updateDoc(doc(c.db, "jobs", tj), {applicantCount: 99}));
    await expectDenied(updateDoc(doc(c.db, "jobs", tj), {applicantCount: deleteField()}));
    assert.equal(await count(), 2);
  });
});

describe("Phone privacy: users/{uid}/private/contact", () => {
  const PH = "+919111122233";
  const priv = (c, uid) => doc(c.db, "users", uid || c.uid, "private", "contact");
  const prof = (c, uid) => doc(c.db, "users", uid || c.uid);
  let contractorJob;

  before(async () => {
    const {phoneOwner: o, phoneOther: x} = clients;
    for (const c of [o, x]) await setDoc(prof(c), {role: "contractor", fullName: "Phone test"});
  });

  test("P1. owner writes (profile save = batch of profile + private) and reads own phone -> allowed", async () => {
    const {phoneOwner: o} = clients;
    const {writeBatch} = require("firebase/firestore");
    const b = writeBatch(o.db);
    b.set(prof(o), {fullName: "Owner", city: "Pune"}, {merge: true});
    b.set(priv(o), {phone: PH, updatedAt: serverTimestamp()}, {merge: true});
    await b.commit();
    const snap = await getDoc(priv(o));
    assert.equal(snap.get("phone"), PH);
  });
  test("P2. another signed-in user cannot read the owner's private phone (get + list) -> denied", async () => {
    const {phoneOther: x, phoneOwner: o} = clients;
    await expectDenied(getDoc(priv(x, o.uid)));
    await expectDenied(getDocs(collection(x.db, "users", o.uid, "private")));
  });
  test("P3. signed-out user cannot read it -> denied", async () => {
    await expectDenied(getDoc(priv(clients.anon, clients.phoneOwner.uid)));
    await expectDenied(getDocs(collection(clients.anon.db, "users", clients.phoneOwner.uid, "private")));
  });
  test("P4. a client cannot write/change/delete another user's phone (private doc or profile)", async () => {
    const {phoneOther: x, phoneOwner: o} = clients;
    await expectDenied(setDoc(priv(x, o.uid), {phone: "+910000000000"}));
    await expectDenied(updateDoc(priv(x, o.uid), {phone: "+910000000000"}));
    await expectDenied(deleteDoc(priv(x, o.uid)));
    await expectDenied(updateDoc(prof(x, o.uid), {phone: "+910000000000"}));
    await expectDenied(updateDoc(prof(x, o.uid), {fullName: "hijacked"}));
    assert.equal((await getDoc(priv(o))).get("phone"), PH);
  });
  test("P5. private doc validation: owner cannot store extra keys / oversize / non-string phone / other doc ids / delete", async () => {
    const o = clients.phoneOwner;
    await expectDenied(setDoc(priv(o), {phone: PH, extra: 1}));
    await expectDenied(setDoc(priv(o), {phone: "9".repeat(21)}));
    await expectDenied(setDoc(priv(o), {phone: 12345}));
    await expectDenied(setDoc(doc(o.db, "users", o.uid, "private", "other"), {phone: PH}));
    await expectDenied(deleteDoc(priv(o)));
    await expectOk(setDoc(priv(o), {phone: PH, updatedAt: serverTimestamp()}, {merge: true}));
  });
  test("P6. phone cannot be (re)introduced on the public profile, even by the owner; empty/unrelated edits still fine", async () => {
    const o = clients.phoneOwner;
    await expectDenied(updateDoc(prof(o), {phone: PH}));
    await expectDenied(setDoc(prof(o), {phone: PH}, {merge: true}));
    await expectDenied(setDoc(doc(clients.phoneOther.db, "users", clients.phoneOther.uid), {role: "labourer", fullName: "x", phone: PH}));
    await expectOk(updateDoc(prof(o), {fullName: "Owner Renamed"}));
    await expectOk(setDoc(prof(o), {phone: ""}, {merge: true}));
  });
  test("P6b. legacy profile phone (pre-migration data): kept value allowed, edits denied, removal allowed", async () => {
    const {phoneOther: x} = clients;
    await admin.firestore().doc(`users/${x.uid}`).update({phone: "+912222233344"}); // simulate legacy production data
    await expectOk(updateDoc(prof(x), {fullName: "Other keeps legacy phone"}));
    await expectDenied(updateDoc(prof(x), {phone: "+913333344455"}));
    await expectOk(updateDoc(prof(x), {phone: deleteField()}));
  });
  test("P7. stranger cannot obtain the contractor's phone via the public profile (get + collection query)", async () => {
    const {stranger, phoneOwner: o} = clients;
    const one = await getDoc(prof(stranger, o.uid));
    assert.equal(one.exists(), true, "public profile still readable");
    assert.ok(!one.get("phone"), "no non-empty phone on the public profile");
    const {query, where} = require("firebase/firestore");
    const list = await getDocs(query(collection(stranger.db, "users"), where("role", "==", "contractor")));
    for (const d of list.docs) assert.ok(!d.get("phone"), `users/${d.id} exposes a phone`);
    assert.ok(list.size > 0);
  });
  test("P8. job doc holds no phone; contractorContacts stays protected and gated by application status", async () => {
    const {phoneOwner: o, stranger, newapp, shortlisted, trigContractor} = clients;
    // Real job + real trigger (phone taken from o's private doc)
    await postJobOk(o).then((id) => { contractorJob = id; });
    const cc = await (async () => { for (let i = 0; i < 80; i++) { const d = await admin.firestore().doc(`contractorContacts/${contractorJob}`).get(); if (d.exists) return d; await new Promise((r) => setTimeout(r, 250)); } })();
    assert.ok(cc, "contractorContacts created by trigger");
    assert.equal(cc.get("contractorPhone"), PH);
    const job = (await admin.firestore().doc(`jobs/${contractorJob}`).get()).data();
    assert.equal(JSON.stringify(job).includes(PH), false);
    assert.equal(Object.keys(job).some((k) => /phone/i.test(k)), false);
    // access: owner yes; stranger / signed-out no; pending applicant no; shortlisted applicant yes; nobody writes
    await expectOk(getDoc(doc(o.db, "contractorContacts", contractorJob)));
    await expectDenied(getDoc(doc(stranger.db, "contractorContacts", contractorJob)));
    await expectDenied(getDoc(doc(clients.anon.db, "contractorContacts", contractorJob)));
    const w = clients.phoneOther;
    await setDoc(doc(w.db, "applications", `${contractorJob}_${w.uid}`), {jobId: contractorJob, workerId: w.uid, contractorId: o.uid, status: "pending"});
    await expectDenied(getDoc(doc(w.db, "contractorContacts", contractorJob)));
    await updateDoc(doc(o.db, "applications", `${contractorJob}_${w.uid}`), {status: "shortlisted"});
    await expectOk(getDoc(doc(w.db, "contractorContacts", contractorJob)));
    await expectDenied(setDoc(doc(o.db, "contractorContacts", contractorJob), {contractorPhone: "x"}));
    await expectDenied(updateDoc(doc(w.db, "contractorContacts", contractorJob), {contractorPhone: "x"}));
  });
  test("P9. deleteAccount (real function) removes the private phone doc with the account", async () => {
    const d = clients.delUser;
    await setDoc(prof(d), {role: "labourer", fullName: "To delete"});
    await setDoc(priv(d), {phone: "+914444455566", updatedAt: serverTimestamp()});
    assert.equal((await admin.firestore().doc(`users/${d.uid}/private/contact`).get()).exists, true);
    await httpsCallable(d.functions, "deleteAccount")({});
    assert.equal((await admin.firestore().doc(`users/${d.uid}/private/contact`).get()).exists, false);
    assert.equal((await admin.firestore().doc(`users/${d.uid}`).get()).exists, false);
  });
  test("P9b. deleteAccount end-to-end: profile, private phone, tokens, jobs (+ contractorContacts), applications, listings and the Auth user are all removed; other users' data is untouched", async () => {
    const d = clients.delFull, other = clients.phoneOther;
    const a = admin.firestore();
    await setDoc(prof(d), {role: "contractor", fullName: "Delete me"});
    await setDoc(priv(d), {phone: "+914444400001", updatedAt: serverTimestamp()});
    await setDoc(doc(d.db, "users", d.uid, "tokens", "tok1"), {at: serverTimestamp()});
    await setDoc(doc(d.db, "listings", `del-listing-${run}`), {vendorId: d.uid, item: "Cement", price: 100});
    const myJob = await postJobOk(d);                                         // real job -> real onJobPosted -> contractorContacts
    await waitFor(async () => (await a.doc(`contractorContacts/${myJob}`).get()).exists);
    await seedJob(`del-other-job-${run}`, other.uid);                         // someone else's job that the user applies to
    await setDoc(doc(d.db, "applications", `del-other-job-${run}_${d.uid}`), {jobId: `del-other-job-${run}`, workerId: d.uid, contractorId: other.uid, status: "pending"});
    await setDoc(doc(other.db, "listings", `keep-listing-${run}`), {vendorId: other.uid, item: "Bricks", price: 50});

    await httpsCallable(d.functions, "deleteAccount")({});

    const gone = async (path) => !(await a.doc(path).get()).exists;
    assert.ok(await gone(`users/${d.uid}`), "profile removed");
    assert.ok(await gone(`users/${d.uid}/private/contact`), "private phone removed");
    assert.ok(await gone(`users/${d.uid}/tokens/tok1`), "push token removed");
    assert.ok(await gone(`listings/del-listing-${run}`), "listing removed");
    assert.ok(await gone(`jobs/${myJob}`), "posted job removed");
    assert.ok(await gone(`applications/del-other-job-${run}_${d.uid}`), "application removed");
    assert.ok(await waitFor(async () => gone(`contractorContacts/${myJob}`)), "contractorContacts (the phone copy) removed by onJobDeleted");
    await assert.rejects(admin.auth().getUser(d.uid), (e) => e.code === "auth/user-not-found", "Auth user deleted");
    assert.ok(!(await gone(`listings/keep-listing-${run}`)), "another user's listing untouched");
    assert.ok(!(await gone(`jobs/del-other-job-${run}`)), "another user's job untouched");
    // the deleted user's old session can no longer act
    assert.notEqual(await callCode(d, "postJob", validJob()), "ok");
  });

  test("P10. legacy-phone migration script: dry-run changes nothing; --apply moves the phone; idempotent; conflicts left alone", async () => {
    const a = admin.firestore(); const id1 = `mig1-${run}`, id2 = `mig2-${run}`, id3 = `mig3-${run}`;
    await a.doc(`users/${id1}`).set({role: "labourer", fullName: "Legacy", phone: "+915550001"});
    await a.doc(`users/${id2}`).set({role: "labourer", fullName: "Conflict", phone: "+915550002"});
    await a.doc(`users/${id2}/private/contact`).set({phone: "+915559999"});
    await a.doc(`users/${id3}`).set({role: "labourer", fullName: "Clean"});
    const script = path.join(__dirname, "..", "..", "scripts", "migrate_user_phone_to_private.js");
    const run_ = (...args) => JSON.parse(execFileSync("node", [script, ...args], {env: process.env, encoding: "utf8"}));
    const dry = run_();
    assert.equal(dry.mode, "DRY-RUN");
    assert.equal((await a.doc(`users/${id1}`).get()).get("phone"), "+915550001");
    assert.equal((await a.doc(`users/${id1}/private/contact`).get()).exists, false);
    const applied = run_("--apply");
    assert.equal(applied.mode, "APPLY");
    assert.equal((await a.doc(`users/${id1}`).get()).get("phone"), undefined);
    assert.equal((await a.doc(`users/${id1}/private/contact`).get()).get("phone"), "+915550001");
    assert.equal((await a.doc(`users/${id2}`).get()).get("phone"), "+915550002", "conflicting docs must be left for a human");
    assert.ok(applied.conflictUids.includes(id2));
    assert.equal(run_("--apply").moved, 0, "idempotent");
    assert.throws(() => execFileSync("node", [script], {env: {...process.env, FIRESTORE_EMULATOR_HOST: ""}, stdio: "pipe"}), /./, "must refuse without emulator/--allow-production");
  });
});

describe("Read-only integrity audit script (seeded anomalies, emulator)", () => {
  test("Q1. scripts/audit_integrity_readonly.js flags every seeded anomaly, prints no phone numbers, and writes nothing", async () => {
    const a = admin.firestore(); const id = `q-${run}`;
    const SECRET = "+919000012345";
    await a.doc(`jobs/${id}-job`).set({postedBy: `${id}-poster`, title: "t", contractorPhone: SECRET});
    await a.doc(`applications/${id}-job_${id}-w1`).set({jobId: `${id}-job`, workerId: `${id}-w1`, contractorId: `${id}-FAKE`, status: "pending"}); // mismatch
    await a.doc(`applications/ghost-${id}_${id}-w2`).set({jobId: `ghost-${id}`, workerId: `${id}-w2`, contractorId: "x", status: "pending"}); // missing job
    await a.doc(`applications/${id}-job_${id}-w3`).set({jobId: `${id}-job`, workerId: `${id}-w3`, contractorId: `${id}-poster`, status: "pending"}); // fine
    await a.doc(`threads/${id}-t1`).set({participants: [`${id}-w1`, `${id}-stranger`], jobId: `${id}-job`}); // not poster+applicant
    await a.doc(`threads/${id}-t2`).set({participants: [`${id}-w3`, `${id}-poster`], jobId: `${id}-job`}); // fine
    await a.doc(`threads/${id}-t3`).set({participants: [`${id}-w3`, `${id}-poster`]}); // no jobId
    await a.doc(`users/${id}-u1`).set({phone: SECRET});
    const before = (await a.collection("jobs").get()).size + (await a.collection("threads").get()).size;
    const out = execFileSync("node", [path.join(__dirname, "..", "..", "scripts", "audit_integrity_readonly.js")], {env: process.env, encoding: "utf8"});
    assert.equal(out.includes(SECRET), false, "audit output must not contain phone numbers");
    const r = JSON.parse(out);
    assert.ok(r.applications.contractorMismatch.ids.includes(`${id}-job_${id}-w1`));
    assert.ok(!r.applications.contractorMismatch.ids.includes(`${id}-job_${id}-w3`));
    assert.ok(r.applications.missingJob.ids.includes(`ghost-${id}_${id}-w2`));
    assert.ok(r.threads.notPosterPlusApplicant.ids.includes(`${id}-t1`));
    assert.ok(!r.threads.notPosterPlusApplicant.ids.includes(`${id}-t2`));
    assert.ok(r.threads.noJobId.ids.includes(`${id}-t3`));
    assert.ok(r.jobs.ids.includes(`${id}-job`) && r.jobs.withNonEmptyContractorPhone >= 1);
    assert.ok(r.users.withPublicPhone >= 1 && r.users.publicOnly >= 1);
    assert.equal((await a.collection("jobs").get()).size + (await a.collection("threads").get()).size, before, "read-only");
    assert.throws(() => execFileSync("node", [path.join(__dirname, "..", "..", "scripts", "audit_integrity_readonly.js")], {env: {...process.env, FIRESTORE_EMULATOR_HOST: ""}, stdio: "pipe"}), /./);
  });
});

describe("Production-finding reproductions against the CURRENT local rules", () => {
  let selfJob;
  before(async () => {
    const c = clients.selfPoster;
    await setDoc(doc(c.db, "users", c.uid), {role: "contractor", fullName: "Self poster"});
    selfJob = `self-${run}`;
    await seedJob(selfJob, c.uid);
  });
  test("S1. poster opening a thread with THEMSELVES (participants [X,X]) on own job -> denied, even after applying to own job", async () => {
    const c = clients.selfPoster;
    await expectOk(setDoc(doc(c.db, "applications", `${selfJob}_${c.uid}`), {jobId: selfJob, workerId: c.uid, contractorId: c.uid, status: "pending"}));  // KNOWN GAP: poster may apply to own job
    await expectDenied(setDoc(doc(c.db, "threads", `${c.uid}_${c.uid}_${selfJob}`), threadData([c.uid, c.uid], selfJob)));
  });
  test("S2. applicant opening a self-thread [W,W] on a job they applied to -> denied", async () => {
    const w = clients.selfApplicant, contractor = clients.selfPoster;
    await expectOk(setDoc(doc(w.db, "applications", `${selfJob}_${w.uid}`), {jobId: selfJob, workerId: w.uid, contractorId: contractor.uid, status: "pending"}));
    await expectDenied(setDoc(doc(w.db, "threads", `${w.uid}_${w.uid}_${selfJob}`), threadData([w.uid, w.uid], selfJob)));
  });
  test("S3. direct (job-less) chat as the Find-screen 'Send message' creates it: jobId null / missing / empty -> denied (either direction)", async () => {
    const {selfPoster: c, selfApplicant: w} = clients;
    const ids = (k) => [`${[c.uid, w.uid].sort().join("_")}${k}`];
    await expectDenied(setDoc(doc(c.db, "threads", ids("a")[0]), {participants: [c.uid, w.uid], jobId: null, createdAt: Timestamp.now()}));
    await expectDenied(setDoc(doc(w.db, "threads", ids("b")[0]), {participants: [c.uid, w.uid], createdAt: Timestamp.now()}));
    await expectDenied(setDoc(doc(c.db, "threads", ids("c")[0]), {participants: [c.uid, w.uid], jobId: "", createdAt: Timestamp.now()}));
    // The app's own openThread(merge:true) shape, jobId null:
    await expectDenied(setDoc(doc(c.db, "threads", ids("d")[0]), {participants: [c.uid, w.uid], names: {}, jobId: null, jobTitle: "", updatedAt: serverTimestamp()}, {merge: true}));
  });
  test("S4. contractorPhone on public jobs: no client can create a job at all; the callable stores no phone; updates cannot add/change one", async () => {
    const {cpA: a, cpB: b} = clients;
    for (const c of [a, b]) await setDoc(doc(c.db, "users", c.uid), {role: "contractor", fullName: "cp"});
    const base = (c, extra = {}) => ({postedBy: c.uid, title: "t", description: "d", wage: 500, status: "open", applicantCount: 0, ...extra});
    // direct client creates are denied outright (with or without a phone)
    for (const extra of [{}, {contractorPhone: ""}, {contractorPhone: "+919000000000"}]) {
      await expectDenied(setDoc(doc(a.db, "jobs", `cp-direct-${run}`), base(a, extra)));
    }
    // the callable ignores client-supplied server-owned fields, including any phone
    const id = await postJobOk(a, {contractorPhone: "+919000000000", postedBy: b.uid, status: "closed", applicantCount: 9, contractorName: "Spoof"});
    const stored = (await admin.firestore().doc(`jobs/${id}`).get()).data();
    assert.equal(stored.postedBy, a.uid);
    assert.equal(stored.status, "open");
    assert.equal(stored.applicantCount, 0);
    assert.equal(stored.contractorName, "cp");
    assert.equal(Object.keys(stored).some((k) => /phone/i.test(k)), false);
    assert.equal(JSON.stringify(stored).includes("+919000000000"), false);
    // update: setting / changing to non-empty denied; empty ok (jobs seeded as a server would)
    await seedJob(`cp-absent-${run}`, a.uid);
    await seedJob(`cp-empty-${run}`, b.uid, {contractorPhone: ""});
    for (const [jid, c] of [[`cp-absent-${run}`, a], [`cp-empty-${run}`, b]]) {
      const r = doc(c.db, "jobs", jid);
      await expectDenied(updateDoc(r, {contractorPhone: "+919000000000"}));
      await expectDenied(setDoc(r, {contractorPhone: "+919000000000"}, {merge: true}));
      await expectOk(updateDoc(r, {title: "still editable", contractorPhone: ""}));
      await expectOk(updateDoc(r, {wage: 600}));
    }
    // legacy job that already has a phone (as the 9 production jobs do)
    const legacy = `cp-legacy-${run}`;
    await seedJob(legacy, a.uid, {contractorPhone: "+919111111111"});
    const lr = doc(a.db, "jobs", legacy);
    await expectDenied(updateDoc(lr, {contractorPhone: "+919222222222"}));
    await expectOk(updateDoc(lr, {title: "legacy edit keeps phone"}));
    await expectOk(updateDoc(lr, {contractorPhone: deleteField()}));
    await expectOk(updateDoc(lr, {title: "after removal"}));
  });
  test("S5. contractorId mismatch cannot be created or produced by editing after the fact -> denied", async () => {
    const w = clients.selfApplicant, other = clients.stranger;
    await expectDenied(setDoc(doc(w.db, "applications", `${selfJob}_${w.uid}x`), {jobId: selfJob, workerId: w.uid, contractorId: other.uid, status: "pending"}));
    await expectDenied(updateDoc(doc(w.db, "applications", `${selfJob}_${w.uid}`), {status: "withdrawn", contractorId: other.uid}));
  });
});

describe("postJob callable (the only job-creation path) — rate limit, validation, server-owned fields", () => {
  const { _test: pj } = require("../../functions/post_job");
  const mkUser = (c, extra = {}) => setDoc(doc(c.db, "users", c.uid), {role: "contractor", fullName: `Name ${c.uid.slice(0, 4)}`, ...extra});
  const jobsBy = async (uid) => (await admin.firestore().collection("jobs").where("postedBy", "==", uid).get()).size;

  test("J1. unauthenticated -> unauthenticated", async () => {
    assert.equal(await callCode(clients.anon, "postJob", validJob()), "functions/unauthenticated");
  });
  test("J2. signed in but no profile -> failed-precondition; nothing created", async () => {
    assert.equal(await callCode(clients.pjNoUser, "postJob", validJob()), "functions/failed-precondition");
    assert.equal(await jobsBy(clients.pjNoUser.uid), 0);
  });
  test("J3. suspended account -> permission-denied; nothing created", async () => {
    await mkUser(clients.pjSusp);
    await admin.firestore().doc(`users/${clients.pjSusp.uid}`).update({suspended: true});
    assert.equal(await callCode(clients.pjSusp, "postJob", validJob()), "functions/permission-denied");
    assert.equal(await jobsBy(clients.pjSusp.uid), 0);
  });

  test("J4. validation: bad payloads are rejected with invalid-argument and do NOT consume the cooldown", async () => {
    const c = clients.pjVal;
    await mkUser(c, {businessName: "Val Builders"});
    const bads = [
      undefined, null, "text", [], {},
      validJob({title: ""}), validJob({title: "   "}), validJob({title: "x".repeat(301)}), validJob({title: 42}),
      validJob({description: "x".repeat(2001)}), validJob({skill: "x".repeat(101)}), validJob({pincode: "1".repeat(11)}),
      validJob({wage: 0}), validJob({wage: -5}), validJob({wage: 100001}), validJob({wage: 1.5}), validJob({wage: "500"}), validJob({wage: null}),
      (() => { const j = validJob(); delete j.wage; return j; })(),
      validJob({workersNeeded: 0}), validJob({workersNeeded: 1001}), validJob({workersNeeded: 2.5}),
      validJob({hoursPerDay: 25}), validJob({hoursPerDay: -1}),
      validJob({startDate: "garbage"}), validJob({startDate: 5}), validJob({startDate: "2026-10-10", endDate: "2026-10-01"}),
      validJob({location: {latitude: 91, longitude: 0}}), validJob({location: {latitude: 0, longitude: 181}}),
      validJob({location: {latitude: "1", longitude: 2}}), validJob({location: {latitude: 1}}), validJob({location: "here"}),
    ];
    for (const [i, b] of bads.entries()) {
      assert.equal(await callCode(c, "postJob", b), "functions/invalid-argument", `bad payload #${i}: ${JSON.stringify(b)?.slice(0, 80)}`);
    }
    assert.equal(await jobsBy(c.uid), 0);
    // ...and a good one still works immediately afterwards (no cooldown was consumed by the rejections)
    assert.equal(await callCode(c, "postJob", validJob({title: "  Trimmed title  "})), "ok");
    assert.equal(await jobsBy(c.uid), 1);
  });

  test("J5. server-owned fields: postedBy/contractorName/status/applicantCount/createdAt decided by the server; extra client fields ignored", async () => {
    const c = clients.pjVal;
    await admin.firestore().doc(`users/${c.uid}`).update({lastJobPostedAt: new Date(Date.now() - 60000)});
    const id = await postJobOk(c, {postedBy: clients.stranger.uid, status: "filled", applicantCount: 50, contractorName: "Spoof",
      contractorPhone: "+919000000000", minWageAtPost: 1, createdAt: "2000-01-01", isAdmin: true, geohash: "evil", suspended: false});
    const j = (await admin.firestore().doc(`jobs/${id}`).get()).data();
    assert.equal(j.postedBy, c.uid);
    assert.equal(j.contractorName, "Val Builders");
    assert.equal(j.status, "open");
    assert.equal(j.applicantCount, 0);
    assert.equal(j.geohash, "");
    assert.ok(j.createdAt && typeof j.createdAt.toDate === "function" && j.createdAt.toDate().getFullYear() >= 2026, "createdAt is a server timestamp");
    for (const k of ["contractorPhone", "isAdmin", "suspended"]) assert.equal(k in j, false, `${k} must not be stored`);
    assert.notEqual(j.minWageAtPost, 1, "minWageAtPost comes from the trigger, not the client");
    assert.equal(j.title, "Test job");
  });

  test("J6. dates and location are stored as Timestamps / GeoPoint with a geo field the app's nearby query can use", async () => {
    const c = clients.pjGeo;
    await mkUser(c);
    const id = await postJobOk(c, {location: {latitude: 28.6139, longitude: 77.2090}, startDate: "2026-10-05T00:00:00.000Z", endDate: "2026-10-09T00:00:00.000Z", hoursPerDay: 8, workersNeeded: 3});
    const j = (await admin.firestore().doc(`jobs/${id}`).get()).data();
    assert.equal(j.location.latitude, 28.6139);
    assert.equal(j.geo.geohash, "ttnfucjbh");
    assert.equal(j.geo.geopoint.latitude, 28.6139);
    assert.equal(j.startDate.toDate().toISOString(), "2026-10-05T00:00:00.000Z");
    assert.equal(j.endDate.toDate().toISOString(), "2026-10-09T00:00:00.000Z");
    assert.equal(j.workersNeeded, 3);
    assert.equal(j.hoursPerDay, 8);
  });

  test("J7. server geohash == the app's GeoFirePoint.geohash (values generated by the Dart package)", () => {
    const cases = [[28.6139, 77.209, "ttnfucjbh"], [19.076, 72.8777, "te7ud2evv"], [13.0827, 80.2707, "tf346tek6"], [0, 0, "7zzzzzzzz"],
      [-33.8688, 151.2093, "r3gx2f77b"], [89.9999, 179.9999, "zzzzzzzzm"], [-90, -180, "000000000"], [90, 180, "zzzzzzzzz"],
      [26.9124, 75.7873, "tsvche68h"], [-0.0001, -0.0001, "7zzzzzzzm"]];
    for (const [lat, lng, want] of cases) assert.equal(pj.encodeGeohash(lat, lng), want, `${lat},${lng}`);
  });

  test("J8. BURST: 8 parallel posts by one user -> exactly 1 job created, 7 refused (this used to accept all 8)", async () => {
    const c = clients.pjBurst;
    await mkUser(c);
    const res = await Promise.all(Array.from({length: 8}, () => callCode(c, "postJob", validJob())));
    assert.equal(res.filter((r) => r === "ok").length, 1, JSON.stringify(res));
    assert.equal(res.filter((r) => r === "functions/resource-exhausted").length, 7, JSON.stringify(res));
    assert.equal(await jobsBy(c.uid), 1);
  });

  test("J9. cooldown is per user: two users posting in parallel both succeed", async () => {
    const {pjIndepA: a, pjIndepB: b} = clients;
    await mkUser(a); await mkUser(b);
    const res = await Promise.all([callCode(a, "postJob", validJob()), callCode(b, "postJob", validJob())]);
    assert.deepEqual(res, ["ok", "ok"]);
  });

  test("J10. refusal carries retryAfterSeconds (1..15); the cooldown boundary is 15s on the server clock", async () => {
    const c = clients.pjIndepA;
    try { await httpsCallable(c.functions, "postJob")(validJob()); assert.fail("should be refused"); }
    catch (e) {
      assert.equal(e.code, "functions/resource-exhausted");
      assert.ok(e.details && e.details.retryAfterSeconds >= 1 && e.details.retryAfterSeconds <= 15, JSON.stringify(e.details));
    }
    const ref = admin.firestore().doc(`users/${c.uid}`);
    await ref.update({lastJobPostedAt: new Date(Date.now() - 12000)});
    assert.equal(await callCode(c, "postJob", validJob()), "functions/resource-exhausted");   // 12s ago: still cooling down
    await ref.update({lastJobPostedAt: new Date(Date.now() - 16000)});
    assert.equal(await callCode(c, "postJob", validJob()), "ok");                             // 16s ago: allowed
  });

  test("J11. direct client job create is denied for everyone, even a valid body from a user who never posted", async () => {
    const c = clients.pjNoUser;
    await mkUser(c);
    await expectDenied(setDoc(doc(c.db, "jobs", `direct-${run}`), {postedBy: c.uid, title: "t", description: "d", wage: 500, status: "open", applicantCount: 0}));
    await expectDenied(setDoc(doc(clients.anon.db, "jobs", `direct-anon-${run}`), {postedBy: "x", title: "t", description: "d", wage: 500, status: "open", applicantCount: 0}));
  });

  test("J12. jobs made by the callable still get the trigger's wage flags and a protected contractorContacts doc", async () => {
    const c = clients.pjGeo;
    await admin.firestore().doc(`users/${c.uid}`).update({lastJobPostedAt: new Date(Date.now() - 60000)});
    const id = await postJobOk(c, {wage: 100, state: "Maharashtra", skill: "Helper"});
    let j; for (let i = 0; i < 80 && !(j = (await admin.firestore().doc(`jobs/${id}`).get())).get("minWageAtPost"); i++) await new Promise((r) => setTimeout(r, 250));
    assert.equal(j.get("belowMinimumWage"), true);
    let cc; for (let i = 0; i < 80 && !(cc = await admin.firestore().doc(`contractorContacts/${id}`).get()).exists; i++) await new Promise((r) => setTimeout(r, 250));
    assert.equal(cc.get("contractorId"), c.uid);
  });
});

describe("Cloud Functions: migration callables", () => {
  const cases = [
    ["migrateContractorPhone", {dryRun: true, batchSize: 10, maxBatches: 1}, "ok"],
    ["verifyMigration", {}, "ok"],
    // No confirm:true is ever sent: admin reaching the confirm check proves auth passed, without deleting anything.
    ["cleanupContractorPhone", {}, "invalid-argument"],
  ];
  for (const [fn, data, adminExpected] of cases) {
    test(`8a. ${fn}: unauthenticated -> unauthenticated`, async () => {
      assert.equal(await code(httpsCallable(clients.anon.functions, fn)(data)), "functions/unauthenticated");
    });
    test(`8b. ${fn}: non-admin -> permission-denied`, async () => {
      assert.equal(await code(httpsCallable(clients.nonadmin.functions, fn)(data)), "functions/permission-denied");
    });
    test(`8c. ${fn}: admin -> passes auth gate (${adminExpected})`, async () => {
      const got = await code(httpsCallable(clients.admin.functions, fn)(data));
      assert.equal(got, adminExpected === "ok" ? "ok" : `functions/${adminExpected}`);
    });
  }
});
