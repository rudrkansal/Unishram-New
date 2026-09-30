import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

/// Thrown when the `deleteAccount` Cloud Function refuses or fails.
class DeleteAccountException implements Exception {
  final String status;
  final String message;
  const DeleteAccountException(this.status, this.message);
  @override
  String toString() => 'DeleteAccountException($status): $message';
}

/// Calls the `deleteAccount` callable Cloud Function (callable protocol over HTTPS). The function removes the
/// user's jobs, applications, listings, push tokens, private contact details, storage files and profile, and
/// then deletes the Firebase Auth user — so the app must call THIS, not just `FirebaseAuth.delete()`.
class AccountApi {
  AccountApi({
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
    return Uri.parse('https://$region-$project.cloudfunctions.net/deleteAccount');
  }

  Future<void> deleteAccount() async {
    final token = await _idToken();
    if (token == null || token.isEmpty) {
      throw const DeleteAccountException('UNAUTHENTICATED', 'Sign in first.');
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
            body: jsonEncode({'data': <String, dynamic>{}}),
          )
          .timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw const DeleteAccountException('DEADLINE_EXCEEDED', 'The request timed out.');
    }
    Map<String, dynamic> body;
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw DeleteAccountException('INTERNAL', 'Unexpected response (${res.statusCode}).');
    }
    if (res.statusCode == 200 && body['result'] is Map && (body['result'] as Map)['ok'] == true) return;
    final err = body['error'];
    if (err is Map) {
      throw DeleteAccountException('${err['status'] ?? 'UNKNOWN'}', '${err['message'] ?? ''}');
    }
    throw DeleteAccountException('UNKNOWN', 'Request failed (${res.statusCode}).');
  }
}
