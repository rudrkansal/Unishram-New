/// Work experience that keeps growing with time.
///
/// A worker enters "1 year" (or "5 months") once. We store that value together with WHEN it was entered
/// (`experienceAsOf`), and every screen shows the value plus the time that has passed since — so "1 year"
/// becomes "2 years" after twelve months without the worker touching their profile, and "5 months"
/// becomes "1 year" after seven more.
library;

/// Whole calendar months from [from] to [to]; never negative. A month only counts once its day has
/// been reached (Jan 31 → Feb 28 is not yet a full month for a value entered on the 31st).
int wholeMonthsBetween(DateTime from, DateTime to) {
  if (!to.isAfter(from)) return 0;
  var months = (to.year - from.year) * 12 + (to.month - from.month);
  if (to.day < from.day) months -= 1;
  return months < 0 ? 0 : months;
}

/// Total months of experience right now: what was entered plus the time elapsed since [asOf].
/// Null when no experience was entered. Without an [asOf] (older profiles) nothing is added.
int? effectiveExperienceMonths({
  required int? years,
  int? months,
  DateTime? asOf,
  DateTime? now,
}) {
  if (years == null) return null;
  final base = years * 12 + (months ?? 0);
  if (asOf == null) return base;
  return base + wholeMonthsBetween(asOf, now ?? DateTime.now());
}

/// "8 mo" while under a year, otherwise whole years ("2 yrs"). [tenPlus] keeps the "10+" wording for
/// someone who chose "10+" until their experience passes 11 years.
String experienceLabel(
  int totalMonths, {
  bool tenPlus = false,
  required String monthsWord,
  required String yearsWord,
  String tenPlusWord = '10+',
}) {
  if (totalMonths < 12) return '$totalMonths $monthsWord';
  final years = totalMonths ~/ 12;
  final shown = (tenPlus && years == 10) ? tenPlusWord : '$years';
  return '$shown $yearsWord';
}

/// Which year pill (0–10, where 10 means "10+") matches [totalMonths] on the edit screen.
int experienceYearsPill(int totalMonths) {
  final years = totalMonths ~/ 12;
  return years > 10 ? 10 : years;
}
