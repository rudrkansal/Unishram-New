import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class ResolvedPlace {
  final String city;
  final String district;
  final String state;
  final String pincode;
  final double lat;
  final double lng;
  const ResolvedPlace({
    required this.city,
    required this.district,
    required this.state,
    required this.pincode,
    required this.lat,
    required this.lng,
  });

  String get line1 => city.isNotEmpty ? city : district;
  String get line2 => [district, state, pincode]
      .where((e) => e.isNotEmpty && e != line1)
      .join(', ');
}

enum LocationFailure { unsupported, denied, off, noAddress }

class LocationResult {
  final ResolvedPlace? place;
  final LocationFailure? failure;
  const LocationResult.success(this.place) : failure = null;
  const LocationResult.failed(this.failure) : place = null;
}

/// GPS first, PIN code second, hand-entry last — the district is derived rather
/// than demanded, because a worker often cannot spell it.
class LocationService {
  Future<LocationResult> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult.failed(LocationFailure.off);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const LocationResult.failed(LocationFailure.denied);
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );

      try {
        final marks =
            await placemarkFromCoordinates(pos.latitude, pos.longitude);
        if (marks.isEmpty) {
          return const LocationResult.failed(LocationFailure.noAddress);
        }
        final m = marks.first;
        final city = (m.locality?.isNotEmpty ?? false)
            ? m.locality!
            : (m.subLocality ?? '');
        final district = (m.subAdministrativeArea?.isNotEmpty ?? false)
            ? m.subAdministrativeArea!
            : (m.locality ?? '');
        return LocationResult.success(ResolvedPlace(
          city: city,
          district: district,
          state: m.administrativeArea ?? '',
          pincode: m.postalCode ?? '',
          lat: pos.latitude,
          lng: pos.longitude,
        ));
      } catch (_) {
        // Coordinates without a readable address are still worth keeping.
        return LocationResult.success(ResolvedPlace(
          city: '',
          district: '',
          state: '',
          pincode: '',
          lat: pos.latitude,
          lng: pos.longitude,
        ));
      }
    } on LocationServiceDisabledException {
      return const LocationResult.failed(LocationFailure.off);
    } catch (_) {
      return const LocationResult.failed(LocationFailure.unsupported);
    }
  }
}
