/// Google Places, configured at build time so no key is ever committed:
///
///   flutter build web --dart-define=GOOGLE_PLACES_API_KEY=xxxxx
///
/// With no key, address autocomplete simply doesn't appear — the plain PIN
/// code field (already free, already works offline) is what's shown instead.
/// Mirrors [VoiceConfig]'s same build-time-key, graceful-degradation shape.
///
/// The key ships inside the compiled web bundle, so it must be restricted in
/// Google Cloud Console by HTTP referrer (your app's domain) before release —
/// an unrestricted key embedded in client JS is a standing invitation to
/// have your quota drained by someone else.
class PlacesConfig {
  const PlacesConfig({this.apiKey = ''});

  final String apiKey;

  bool get hasKey => apiKey.isNotEmpty;

  static PlacesConfig fromEnvironment() {
    const key = String.fromEnvironment('GOOGLE_PLACES_API_KEY');
    return const PlacesConfig(apiKey: key);
  }
}
