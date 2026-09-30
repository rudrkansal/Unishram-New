import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:labour_marketplace/backend/models.dart';
import 'package:labour_marketplace/backend/post_job_api.dart';

JobDoc _job({GeoPoint? location}) => JobDoc(
      id: '',
      postedBy: 'client-claims-to-be-someone-else',
      title: 'Site mason',
      skill: 'Mason',
      wage: 700,
      contractorName: 'Spoofed Name',
      contractorPhone: '+919999900000',
      description: 'desc',
      workersNeeded: 3,
      address: 'Rohini, Delhi',
      area: 'Delhi',
      pincode: '110085',
      state: 'Delhi',
      location: location,
      startDate: DateTime.utc(2026, 10, 5),
      endDate: DateTime.utc(2026, 10, 9),
      hoursPerDay: 8,
      status: 'filled',
      applicantCount: 99,
    );

PostJobApi _api(MockClientHandler h, {String? token = 'tok'}) => PostJobApi(
      client: MockClient(h),
      idToken: () async => token,
      projectId: 'unishram-india',
    );

void main() {
  group('payload contains only client-controlled fields', () {
    final payload = PostJobApi.payloadFor(_job(location: const GeoPoint(28.6, 77.2)));

    test('server-decided fields are never sent', () {
      for (final k in [
        'postedBy', 'status', 'applicantCount', 'createdAt', 'contractorName',
        'contractorPhone', 'geo', 'geohash', 'minWageAtPost',
      ]) {
        expect(payload.containsKey(k), isFalse, reason: '$k must not be sent');
      }
      expect(jsonEncode(payload).contains('+919999900000'), isFalse);
    });

    test('job content is sent', () {
      expect(payload['title'], 'Site mason');
      expect(payload['wage'], 700);
      expect(payload['workersNeeded'], 3);
      expect(payload['hoursPerDay'], 8);
      expect(payload['startDate'], '2026-10-05T00:00:00.000Z');
      expect(payload['location'], {'latitude': 28.6, 'longitude': 77.2});
    });

    test('no location / dates -> keys omitted', () {
      final p = PostJobApi.payloadFor(const JobDoc(
          id: '', postedBy: 'x', title: 't', skill: 's', wage: 1));
      expect(p.containsKey('location'), isFalse);
      expect(p.containsKey('startDate'), isFalse);
      expect(p.containsKey('endDate'), isFalse);
    });
  });

  group('request', () {
    test('POSTs to the asia-south1 callable with the ID token and {data: ...}', () async {
      late http.Request seen;
      final api = _api((req) async {
        seen = req;
        return http.Response(jsonEncode({'result': {'jobId': 'job123'}}), 200);
      });
      final id = await api.post(_job());
      expect(id, 'job123');
      expect(seen.method, 'POST');
      expect(seen.url.toString(),
          'https://asia-south1-unishram-india.cloudfunctions.net/postJob');
      expect(seen.headers['Authorization'], 'Bearer tok');
      expect((jsonDecode(seen.body) as Map).keys, ['data']);
    });

    test('signed out (no token) -> UNAUTHENTICATED, nothing is sent', () async {
      var called = false;
      final api = _api((req) async {
        called = true;
        return http.Response('{}', 200);
      }, token: null);
      await expectLater(
          api.post(_job()),
          throwsA(isA<PostJobException>()
              .having((e) => e.status, 'status', 'UNAUTHENTICATED')));
      expect(called, isFalse);
    });
  });

  group('server refusals surface as PostJobException', () {
    test('cooldown -> isCooldown', () async {
      final api = _api((req) async => http.Response(
          jsonEncode({'error': {'status': 'RESOURCE_EXHAUSTED', 'message': 'Please wait 9s'}}),
          429));
      await expectLater(
          api.post(_job()),
          throwsA(isA<PostJobException>()
              .having((e) => e.isCooldown, 'isCooldown', isTrue)));
    });

    test('invalid argument is not a cooldown', () async {
      final api = _api((req) async => http.Response(
          jsonEncode({'error': {'status': 'INVALID_ARGUMENT', 'message': 'wage'}}), 400));
      await expectLater(
          api.post(_job()),
          throwsA(isA<PostJobException>()
              .having((e) => e.isCooldown, 'isCooldown', isFalse)));
    });

    test('garbage / empty responses never look like success', () async {
      for (final res in [
        http.Response('not json', 200),
        http.Response('{}', 200),
        http.Response(jsonEncode({'result': {}}), 200),
        http.Response(jsonEncode({'result': {'jobId': ''}}), 200),
        http.Response('{}', 500),
      ]) {
        final api = _api((req) async => res);
        await expectLater(api.post(_job()), throwsA(isA<PostJobException>()));
      }
    });
  });
}
