import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/catalog.dart';
import 'models.dart';
import 'repositories.dart';

/// Maps Firestore documents onto the view models the screens already use, so
/// switching a screen from sample data to live data changes only where the list
/// comes from — not how it is drawn.

String _ago(DateTime? then) {
  if (then == null) return 'Just now';
  final d = DateTime.now().difference(then);
  if (d.inMinutes < 1) return 'Just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 30) return '${d.inDays}d ago';
  return '${(d.inDays / 30).floor()}mo ago';
}

String _iso(DateTime? d) => d == null
    ? ''
    : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _duration(DateTime? start, DateTime? end, int hoursPerDay) =>
    formatJobDuration(
        _iso(start), _iso(end), hoursPerDay == 0 ? '' : '$hoursPerDay');

String _distance(GeoPoint? from, GeoPoint? to) {
  final km = JobRepository.distanceKm(from, to);
  if (km == null) return '';
  return km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(1)} km';
}

extension JobDocView on JobDoc {
  Job toJob({GeoPoint? viewerLocation}) => Job(
        id: id,
        title: title,
        skill: skill,
        area: area.isEmpty ? address : area,
        location: address,
        distance: _distance(viewerLocation, location),
        wage: wage,
        contractor: contractorName,
        contractorPhone: contractorPhone,
        postedAgo: _ago(createdAt),
        duration: _duration(startDate, endDate, hoursPerDay),
        desc: description,
        contractorUid: postedBy,
        startDateLabel: formatJobDateLabel(_iso(startDate)),
        endDateLabel: formatJobDateLabel(_iso(endDate)),
        durationSpan: formatJobDurationSpan(
            _iso(startDate), _iso(endDate), hoursPerDay == 0 ? '' : '$hoursPerDay'),
        endDate: endDate,
        minWageAtPost: minWageAtPost,
      );
}

extension UserDocView on UserDoc {
  /// A worker card. Experience reads in years, or months for a newcomer.
  Worker toWorker() => Worker(
        uid,
        fullName,
        skillById(primarySkillId)?.jobLabel ?? '',
        _experience(),
        [city, state].where((e) => e.isNotEmpty).join(', '),
        ratingAverage,
        expectedWage,
        '', // other users' phones are private — never shown from a public profile
        available: availability == 'available',
      );

  Contractor toContractor() => Contractor(
        uid,
        businessName.isNotEmpty ? businessName : fullName,
        [city, state].where((e) => e.isNotEmpty).join(', '),
        ratingAverage,
        ratingCount == 0
            ? 'New'
            : '$ratingCount ${ratingCount == 1 ? 'review' : 'reviews'}',
        '', // other users' phones are private — never shown from a public profile
      );

  String _experience() {
    if (experienceYears == null) return '—';
    if (experienceYears == 0 && (experienceMonths ?? 0) > 0) {
      return '$experienceMonths mo';
    }
    return '$experienceYears yrs';
  }
}

extension ListingDocView on ListingDoc {
  VendorItem toVendorItem(String vendorName) => VendorItem(id, item, vendorName,
      [area, state].where((e) => e.isNotEmpty).join(', '), price, unit);
}

extension ReviewDocView on ReviewDoc {
  Review toReview() =>
      Review(id, byName.isEmpty ? 'A client' : byName, rating, comment);
}
