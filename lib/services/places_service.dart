import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'places_config.dart';

class PlaceSuggestion {
  final String placeId;
  final String description;
  const PlaceSuggestion(this.placeId, this.description);
}

class ResolvedAddress {
  final String formattedAddress;
  final String city;
  final String district;
  final String state;
  final String pincode;
  final double lat;
  final double lng;
  const ResolvedAddress({
    required this.formattedAddress,
    required this.city,
    required this.district,
    required this.state,
    required this.pincode,
    required this.lat,
    required this.lng,
  });
}

/// Google Places Autocomplete + Place Details, for the one field in this app
/// where it actually earns its cost: a client typing a one-off project
/// address. Every other address-shaped field (a worker's or contractor's own
/// location) is captured once via GPS/PIN, which is free — this is reserved
/// for the address a person actually has to type out.
class PlacesService {
  PlacesService({PlacesConfig? config, http.Client? client})
      : config = config ?? PlacesConfig.fromEnvironment(),
        _client = client ?? http.Client();

  final PlacesConfig config;
  final http.Client _client;

  bool get available => config.hasKey;

  /// One token per address-search session, so Google bills the whole
  /// type-then-pick sequence as a single (cheaper) session rather than a
  /// request per keystroke.
  String newSessionToken() =>
      List.generate(16, (_) => Random.secure().nextInt(16).toRadixString(16))
          .join();

  Future<List<PlaceSuggestion>> autocomplete(
    String input, {
    required String sessionToken,
  }) async {
    if (!available || input.trim().length < 3) return const [];
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      {
        'input': input,
        'key': config.apiKey,
        'components': 'country:in',
        'sessiontoken': sessionToken,
      },
    );
    try {
      final response =
          await _client.get(uri).timeout(const Duration(seconds: 6));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') return const [];
      final predictions = data['predictions'] as List;
      return predictions
          .cast<Map<String, dynamic>>()
          .map(
              (p) => PlaceSuggestion('${p['place_id']}', '${p['description']}'))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<ResolvedAddress?> details(
    String placeId, {
    required String sessionToken,
  }) async {
    if (!available) return null;
    final uri =
        Uri.https('maps.googleapis.com', '/maps/api/place/details/json', {
      'place_id': placeId,
      'key': config.apiKey,
      'fields': 'formatted_address,address_component,geometry',
      'sessiontoken': sessionToken,
    });
    try {
      final response =
          await _client.get(uri).timeout(const Duration(seconds: 6));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') return null;
      final result = data['result'] as Map<String, dynamic>;
      final geometry = (result['geometry'] as Map<String, dynamic>)['location']
          as Map<String, dynamic>;
      final components =
          (result['address_components'] as List).cast<Map<String, dynamic>>();

      String component(String type) {
        for (final c in components) {
          if ((c['types'] as List).contains(type)) return '${c['long_name']}';
        }
        return '';
      }

      return ResolvedAddress(
        formattedAddress: '${result['formatted_address'] ?? ''}',
        city: component('locality').isNotEmpty
            ? component('locality')
            : component('sublocality'),
        district: component('administrative_area_level_2'),
        state: component('administrative_area_level_1'),
        pincode: component('postal_code'),
        lat: (geometry['lat'] as num).toDouble(),
        lng: (geometry['lng'] as num).toDouble(),
      );
    } catch (_) {
      return null;
    }
  }
}
