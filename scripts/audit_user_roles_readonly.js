#!/usr/bin/env node
/**
 * READ-ONLY role/discoverability audit. Only .get() reads — no writes, no deletes.
 * Prints shortened uids, roles and the fields the Find queries depend on; never names or phones.
 *
 *   emulator:     FIRESTORE_EMULATOR_HOST=127.0.0.1:PORT GCLOUD_PROJECT=demo-x node scripts/audit_user_roles_readonly.js
 *   real project: GCLOUD_PROJECT=unishram-india node scripts/audit_user_roles_readonly.js --allow-production
 */
const path = require("path");
const admin = require(path.join(__dirname, "..", "functions", "node_modules", "firebase-admin"));
if (!process.env.FIRESTORE_EMULATOR_HOST && !process.argv.includes("--allow-production")) {
  console.error("Refusing to read a real project without --allow-production."); process.exit(2);
}
admin.initializeApp({projectId: process.env.GCLOUD_PROJECT || undefined});
const db = admin.firestore();

const short = (id) => `${id.slice(0, 6)}…`;
const kind = (v) => (v === undefined ? "MISSING" : v === null ? "null" : typeof v);

(async () => {
  const snap = await db.collection("users").get();
  const byRole = {};
  const rows = [];
  for (const d of snap.docs) {
    const x = d.data();
    const priv = await d.ref.collection("private").doc("contact").get();
    byRole[x.role ?? "MISSING"] = (byRole[x.role ?? "MISSING"] || 0) + 1;
    rows.push({
      uid: short(d.id),
      role: x.role ?? "MISSING",
      // Find queries need suspended == false (a missing field is NOT matched) and a numeric ratingAverage.
      suspended: `${kind(x.suspended)}:${x.suspended}`,
      ratingAverage: kind(x.ratingAverage),
      hasCity: !!x.city, hasState: !!x.state, hasGeo: !!(x.geo && x.geo.geopoint),
      // Which onboarding the stored fields came from.
      contractorFields: !!(x.contractorType || x.businessName || (x.workTypeIds || []).length),
      clientFields: !!(x.clientType || x.projectAddress),
      labourerFields: !!(x.primarySkillId || (x.skillIds || []).length),
      // Call now reads the private contact doc (or a legacy profile phone).
      privatePhone: !!(priv.exists && priv.get("phone")),
      legacyPhone: !!x.phone,
    });
  }
  console.log("users by role:", byRole);
  console.table(rows);
  const auth = await admin.auth().listUsers(1000);
  console.log(`auth accounts: ${auth.users.length}, profiles: ${snap.size}`);
  process.exit(0);
})().catch((e) => { console.error(e.message); process.exit(1); });
