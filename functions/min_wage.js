/**
 * Legal daily minimum wages — the SERVER copy, generated from `kMinWageTable`, `kDefaultMinWage` and the skill
 * list in lib/data/catalog.dart (values rounded the same way the app rounds them). `postJob` uses it to refuse a
 * wage below the minimum, and `onJobPosted` uses it to record `minWageAtPost`. Keep it identical to the app.
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
  "Ladakh": {unskilled: 450, semi_skilled: 450, skilled: 450},
  "Dadra & Nagar Haveli and Daman & Diu": {unskilled: 487, semi_skilled: 498, skilled: 508},
};

const DEFAULT_MIN_WAGE = {unskilled: 556, semi_skilled: 650, skilled: 781};

// Wage category by the trade name a job carries (the short "job label", or the full display name).
const SKILL_CATEGORY = {
  "Mason": "skilled",
  "Helper / General Labourer": "unskilled",
  "Helper": "unskilled",
  "Carpenter": "skilled",
  "Electrician": "skilled",
  "Plumber": "skilled",
  "Painter": "skilled",
  "Welder / Fabricator": "skilled",
  "Welder": "skilled",
  "Bar Bender / Steel Worker": "skilled",
  "Bar Bender": "skilled",
  "Shuttering / Formwork Worker": "skilled",
  "Shuttering": "skilled",
  "Tile & Flooring Worker": "skilled",
  "Waterproofing Worker": "semi_skilled",
  "POP / False Ceiling Worker": "skilled",
  "POP": "skilled",
  "Glass / Aluminium Worker": "skilled",
  "Glass": "skilled",
  "Scaffolding Worker": "semi_skilled",
  "Excavator / JCB Operator": "skilled",
  "Excavator": "skilled",
  "Crane Operator": "skilled",
  "Other Machine Operator": "skilled",
  "Road Worker": "semi_skilled",
  "Paving Worker": "semi_skilled",
  "Drainage / Sewerage Worker": "semi_skilled",
  "Drainage": "semi_skilled",
  "Earthwork Worker": "unskilled",
  "Gardener": "unskilled",
  "Site Supervisor / Foreman": "skilled",
  "Site Supervisor": "skilled",
  "Surveyor": "skilled",
  "Civil Technician": "skilled",
  "Other Skilled Worker": "skilled",
};

function categoryFor(skill) {
  return Object.prototype.hasOwnProperty.call(SKILL_CATEGORY, skill) ? SKILL_CATEGORY[skill] : "skilled";
}

/** The minimum daily wage for a job in [state] for [skill]; an unknown state uses the national floor. */
function minimumWageFor(state, skill) {
  const row = Object.prototype.hasOwnProperty.call(MIN_WAGE, state) ? MIN_WAGE[state] : DEFAULT_MIN_WAGE;
  return row[categoryFor(skill)];
}

module.exports = {MIN_WAGE, DEFAULT_MIN_WAGE, SKILL_CATEGORY, categoryFor, minimumWageFor};
