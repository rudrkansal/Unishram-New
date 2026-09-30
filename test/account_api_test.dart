import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:labour_marketplace/backend/account_api.dart';

AccountApi _api(MockClientHandler h, {String? token = 'tok'}) => AccountApi(
      client: MockClient(h),
      idToken: () async => token,
      projectId: 'unishram-india',
    );

// Account deletion must reach the server function — FirebaseAuth.delete() alone leaves the user's data behind.
void main() {
  test('calls the asia-south1 deleteAccount callable with the ID token', () async {
    late http.Request seen;
    final api = _api((req) async {
      seen = req;
      return http.Response(jsonEncode({'result': {'ok': true}}), 200);
    });
    await api.deleteAccount();
    expect(seen.method, 'POST');
    expect(seen.url.toString(),
        'https://asia-south1-unishram-india.cloudfunctions.net/deleteAccount');
    expect(seen.headers['Authorization'], 'Bearer tok');
    expect(jsonDecode(seen.body), {'data': <String, dynamic>{}});
  });

  test('signed out -> UNAUTHENTICATED and nothing is sent', () async {
    var called = false;
    final api = _api((req) async {
      called = true;
      return http.Response('{}', 200);
    }, token: null);
    await expectLater(api.deleteAccount(),
        throwsA(isA<DeleteAccountException>().having((e) => e.status, 'status', 'UNAUTHENTICATED')));
    expect(called, isFalse);
  });

  test('anything but an explicit ok:true is a failure (never a silent success)', () async {
    for (final res in [
      http.Response('{}', 200),
      http.Response(jsonEncode({'result': {}}), 200),
      http.Response(jsonEncode({'result': {'ok': false}}), 200),
      http.Response('not json', 200),
      http.Response(jsonEncode({'error': {'status': 'INTERNAL', 'message': 'x'}}), 500),
      http.Response('{}', 503),
    ]) {
      await expectLater(_api((req) async => res).deleteAccount(), throwsA(isA<DeleteAccountException>()));
    }
  });
}
