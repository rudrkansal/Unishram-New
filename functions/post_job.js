/**
 * postJob — the ONLY way a job is created.
 *
 * Clients cannot create `jobs` documents directly (firestore.rules: `allow create: if false`), so the
 * 15-second post cooldown is enforced here, inside one Firestore transaction that
 *   1. reads users/{uid}.lastJobPostedAt,
 *   2. rejects the call if the cooldown has not elapsed,
 *   3. creates the job and writes the new lastJobPostedAt together.
 * Transactions on the same user document serialize, so a burst of parallel calls can create at most one job.
 *
 * The payload is a whitelist: postedBy, status, applicantCount, createdAt, contractorName, contractorPhone and
 * the geohash are decided here, never taken from the client.
 */
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const {FieldValue, Timestamp, GeoPoint} = require("firebase-admin/firestore");

const COOLDOWN_MS = 15 * 1000;
const BASE32 = "0123456789bcdefghjkmnpqrstuvwxyz";

/** Same algorithm and length (9) as geoflutterfire_plus' GeoFirePoint.geohash, which the app queries on. */
function encodeGeohash(latitude, longitude, length = 9) {
  let chars = "";
  let bits = 0;
  let bitsTotal = 0;
  let hashValue = 0;
  let maxLat = 90.0;
  let minLat = -90.0;
  let maxLng = 180.0;
  let minLng = -180.0;
  while (chars.length < length) {
    if (bitsTotal % 2 === 0) {
      const mid = (maxLng + minLng) / 2;
      if (longitude > mid) { hashValue = (hashValue << 1) + 1; minLng = mid; } else { hashValue = (hashValue << 1); maxLng = mid; }
    } else {
      const mid = (maxLat + minLat) / 2;
      if (latitude > mid) { hashValue = (hashValue << 1) + 1; minLat = mid; } else { hashValue = (hashValue << 1); maxLat = mid; }
    }
    bits++;
    bitsTotal++;
    if (bits === 5) {
      chars += BASE32[hashValue];
      bits = 0;
      hashValue = 0;
    }
  }
  return chars;
}

const bad = (msg) => new HttpsError("invalid-argument", msg);

function str(data, key, {min = 0, max, required = false} = {}) {
  const v = data[key];
  if (v === undefined || v === null) {
    if (required) throw bad(`${key} is required.`);
    return "";
  }
  if (typeof v !== "string") throw bad(`${key} must be text.`);
  const t = v.trim();
  if (t.length < min || (required && t.length === 0)) throw bad(`${key} is required.`);
  if (t.length > max) throw bad(`${key} is too long (max ${max}).`);
  return t;
}

function int(data, key, {min, max, def}) {
  const v = data[key];
  if (v === undefined || v === null || v === "") {
    if (def === undefined) throw bad(`${key} is required.`);
    return def;
  }
  if (typeof v !== "number" || !Number.isInteger(v)) throw bad(`${key} must be a whole number.`);
  if (v < min || v > max) throw bad(`${key} must be between ${min} and ${max}.`);
  return v;
}

function date(data, key) {
  const v = data[key];
  if (v === undefined || v === null || v === "") return null;
  if (typeof v !== "string") throw bad(`${key} must be an ISO date string.`);
  const d = new Date(v);
  if (Number.isNaN(d.getTime())) throw bad(`${key} is not a valid date.`);
  return d;
}

/** Validates the client payload and returns only the fields a client may influence. */
function parseJobInput(data) {
  if (!data || typeof data !== "object" || Array.isArray(data)) throw bad("A job payload is required.");
  const out = {
    title: str(data, "title", {max: 300, required: true}),
    skill: str(data, "skill", {max: 100}),
    description: str(data, "description", {max: 2000}),
    wage: int(data, "wage", {min: 1, max: 100000}),
    workersNeeded: int(data, "workersNeeded", {min: 1, max: 1000, def: 1}),
    address: str(data, "address", {max: 300}),
    area: str(data, "area", {max: 300}),
    pincode: str(data, "pincode", {max: 10}),
    state: str(data, "state", {max: 100}),
    hoursPerDay: int(data, "hoursPerDay", {min: 0, max: 24, def: 0}),
    startDate: date(data, "startDate"),
    endDate: date(data, "endDate"),
    location: null,
  };
  if (out.startDate && out.endDate && out.endDate < out.startDate) throw bad("endDate is before startDate.");
  const loc = data.location;
  if (loc !== undefined && loc !== null) {
    const {latitude, longitude} = loc;
    if (typeof latitude !== "number" || typeof longitude !== "number" || !Number.isFinite(latitude) ||
        !Number.isFinite(longitude) || latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
      throw bad("location must be a valid latitude/longitude.");
    }
    out.location = {latitude, longitude};
  }
  return out;
}

exports.postJob = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in first.");
  const uid = request.auth.uid;
  const input = parseJobInput(request.data);

  const db = admin.firestore();
  const userRef = db.collection("users").doc(uid);
  const jobRef = db.collection("jobs").doc();

  await db.runTransaction(async (t) => {
    const user = await t.get(userRef);
    if (!user.exists) throw new HttpsError("failed-precondition", "Complete your profile before posting a job.");
    if (user.get("suspended") === true) throw new HttpsError("permission-denied", "This account cannot post jobs.");

    const now = Timestamp.now();
    const last = user.get("lastJobPostedAt");
    if (last && typeof last.toMillis === "function") {
      const elapsed = now.toMillis() - last.toMillis();
      if (elapsed < COOLDOWN_MS) {
        const retryAfterSeconds = Math.ceil((COOLDOWN_MS - elapsed) / 1000);
        throw new HttpsError("resource-exhausted", `Please wait ${retryAfterSeconds}s before posting another job.`,
            {retryAfterSeconds});
      }
    }

    const doc = {
      postedBy: uid,
      contractorName: user.get("businessName") || user.get("fullName") || "",
      title: input.title,
      skill: input.skill,
      description: input.description,
      wage: input.wage,
      workersNeeded: input.workersNeeded,
      address: input.address,
      area: input.area,
      pincode: input.pincode,
      state: input.state,
      geohash: "",
      startDate: input.startDate ? Timestamp.fromDate(input.startDate) : null,
      endDate: input.endDate ? Timestamp.fromDate(input.endDate) : null,
      hoursPerDay: input.hoursPerDay,
      status: "open",
      applicantCount: 0,
      createdAt: FieldValue.serverTimestamp(),
    };
    if (input.location) {
      doc.location = new GeoPoint(input.location.latitude, input.location.longitude);
      doc.geo = {
        geopoint: new GeoPoint(input.location.latitude, input.location.longitude),
        geohash: encodeGeohash(input.location.latitude, input.location.longitude),
      };
    }
    t.create(jobRef, doc);
    t.set(userRef, {lastJobPostedAt: now}, {merge: true});
  });

  return {jobId: jobRef.id};
});

exports._test = {encodeGeohash, parseJobInput, COOLDOWN_MS};
