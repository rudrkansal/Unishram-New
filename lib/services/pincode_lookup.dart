import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/catalog.dart';

/// Instant, offline-safe PIN lookup — a small bundled sample used to fill the
/// city/district/state fields the moment someone finishes typing, before any
/// network reply (if one is coming) arrives.
abstract class PincodeLookup {
  PinArea? lookup(String pincode);
}

class LocalPincodeLookup implements PincodeLookup {
  const LocalPincodeLookup();

  @override
  PinArea? lookup(String pincode) => kPinAreas[pincode];
}

/// India Post's own public directory — free, unlimited, no API key, and the
/// authoritative source for every real Indian PIN code. The bundled
/// [LocalPincodeLookup] only covers a small sample; this fills in the rest
/// once a reply arrives, which is why callers treat it as a refinement
/// rather than the first thing shown on screen.
///
/// Calls our own `lookupPincode` Cloud Function rather than India Post
/// directly — India Post's API sends no CORS headers, so Flutter web calling
/// it directly gets silently blocked by the browser. The Cloud Function
/// proxies the same lookup server-side and adds its own CORS header.
class IndiaPostPincodeLookup {
  const IndiaPostPincodeLookup({http.Client? client}) : _client = client;
  final http.Client? _client;

  static const _functionBase =
      'https://asia-south1-unishram-india.cloudfunctions.net/lookupPincode';

  Future<PinArea?> lookup(String pincode) async {
    final client = _client ?? http.Client();
    try {
      final response = await client
          .get(Uri.parse('$_functionBase?pincode=$pincode'))
          .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return null;

      final office = jsonDecode(response.body);
      if (office is! Map) return null;

      final district = '${office['district'] ?? ''}'.trim();
      final state = '${office['state'] ?? ''}'.trim();
      final name = '${office['name'] ?? ''}'.trim();
      if (district.isEmpty && state.isEmpty) return null;
      return PinArea(name.isEmpty ? district : name, district, state);
    } catch (_) {
      // Offline, timed out, or the service is down — the local sample (or a
      // plain "not found" note) already covers the user in the meantime.
      return null;
    } finally {
      if (_client == null) client.close();
    }
  }
}
