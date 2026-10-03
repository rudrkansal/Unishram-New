import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

import 'models.dart';

/// Thrown when the `postJob` Cloud Function refuses or fails.
class PostJobException implements Exception {
  final String status; // callable status, e.g. RESOURCE_EXHAUSTED
  final String message;
  const PostJobException(this.status, this.message);

  /// The server-side 15 s post cooldown has not elapsed.
  bool get isCooldown => status == 'RESOURCE_EXHAUSTED';

  @override
  String toString() => 'PostJobException($status): $message';
}

/// Calls the `postJob` callable Cloud Function over HTTPS (the documented callable protocol), so no
/// extra plugin is needed. Jobs can only be created this way: firestore.rules deny client creates,
/// and the function enforces the post cooldown transactionally.
class PostJobApi {
  PostJobApi({
    http.Client? client,
    Future<String?> Function()? idToken,
    String? projectId,
    this.region = 'asia-south1',
  })  : _client = client ?? http.Client(),
        _idToken = idToken ?? _currentIdToken,
        _projectId = projectId;

  final http.Client _client;
  final Future<String?> Function() _idToken;
  final String? _projectId;
  final String region;

  static Future<String?> _currentIdToken() async =>
      FirebaseAuth.instance.currentUser?.getIdToken();

  Uri get endpoint {
    final project = _projectId ?? Firebase.app().options.projectId;
    return Uri.parse('https://$region-$project.cloudfunctions.net/postJob');
  }

  /// Only the fields a client may influence. postedBy, status, applicantCount, createdAt,
  /// contractorName and any phone number are decided by the server and are never sent.
  static Map<String, dynamic> payloadFor(JobDoc job) => {
        'title': job.title,
        'skill': job.skill,
        'description': job.description,
        'wage': job.wage,
        'workersNeeded': job.workersNeeded,
        'address': job.address,
        'area': job.area,
        'pincode': job.pincode,
        'state': job.state,
        'hoursPerDay': job.hoursPerDay,
        if (job.startDate != null)
          'startDate': job.startDate!.toUtc().toIso8601String(),
        if (job.endDate != null)
          'endDate': job.endDate!.toUtc().toIso8601String(),
        if (job.location != null)
          'location': {
            'latitude': job.location!.latitude,
            'longitude': job.location!.longitude,
          },
      };

  /// Posts [job] and returns the new job id.
  Future<String> post(JobDoc job) async {
    final token = await _idToken();
    if (token == null || token.isEmpty) {
      throw const PostJobException('UNAUTHENTICATED', 'Sign in first.');
    }
    final http.Response res;
    try {
      res = await _client
          .post(
            endpoint,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'data': payloadFor(job)}),
          )
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw const PostJobException('DEADLINE_EXCEEDED', 'The request timed out.');
    }
    Map<String, dynamic> body;
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw PostJobException('INTERNAL', 'Unexpected response (${res.statusCode}).');
    }
    if (res.statusCode == 200 && body['result'] is Map) {
      final id = (body['result'] as Map)['jobId'];
      if (id is String && id.isNotEmpty) return id;
      throw const PostJobException('INTERNAL', 'The server returned no job id.');
    }
    final err = body['error'];
    if (err is Map) {
      throw PostJobException(
          '${err['status'] ?? 'UNKNOWN'}', '${err['message'] ?? ''}');
    }
    throw PostJobException('UNKNOWN', 'Request failed (${res.statusCode}).');
  }
}
