import 'package:flutter_test/flutter_test.dart';
import 'package:labour_marketplace/state/app_state.dart';

// The full send/verify flow talks to Firebase through AuthRepository, which
// this project's test suite has no mock for, so the throttle-setting code
// inside sendOtp()/verifyOtp()'s onError/catch branches can't be exercised
// here. What IS pure, deterministic logic — the two countdown getters and
// resetDemo()'s cleanup — is covered directly.
void main() {
  group('OTP throttle cooldowns', () {
    test('otpSendThrottleSecondsLeft is 0 with no throttle set', () {
      final app = AppState();
      expect(app.otpSendThrottleSecondsLeft, 0);
    });

    test('otpSendThrottleSecondsLeft counts down from a future timestamp', () {
      final app = AppState();
      app.otpSendThrottledUntil =
          DateTime.now().add(const Duration(seconds: 90));
      expect(app.otpSendThrottleSecondsLeft, greaterThan(0));
      expect(app.otpSendThrottleSecondsLeft, lessThanOrEqualTo(91));
    });

    test('otpSendThrottleSecondsLeft is 0 once the timestamp is past', () {
      final app = AppState();
      app.otpSendThrottledUntil =
          DateTime.now().subtract(const Duration(seconds: 1));
      expect(app.otpSendThrottleSecondsLeft, 0);
    });

    test('otpVerifyThrottleSecondsLeft is independent of the send throttle',
        () {
      final app = AppState();
      app.otpSendThrottledUntil =
          DateTime.now().add(const Duration(seconds: 90));
      expect(app.otpVerifyThrottleSecondsLeft, 0);

      app.otpVerifyThrottledUntil =
          DateTime.now().add(const Duration(seconds: 45));
      expect(app.otpVerifyThrottleSecondsLeft, greaterThan(0));
      // The send throttle set earlier must still be untouched.
      expect(app.otpSendThrottleSecondsLeft, greaterThan(0));
    });

    test('resetDemo clears both throttle timestamps', () async {
      final app = AppState();
      app.otpSendThrottledUntil =
          DateTime.now().add(const Duration(minutes: 2));
      app.otpVerifyThrottledUntil =
          DateTime.now().add(const Duration(minutes: 2));

      await app.resetDemo();

      expect(app.otpSendThrottledUntil, isNull);
      expect(app.otpVerifyThrottledUntil, isNull);
      expect(app.otpSendThrottleSecondsLeft, 0);
      expect(app.otpVerifyThrottleSecondsLeft, 0);
    });

    test('resetDemo also clears the pre-existing OTP session fields', () async {
      final app = AppState();
      app.otpSent = true;
      app.otpCode = '123456';
      app.otpSentAt = DateTime.now();
      app.otpResendCount = 3;

      await app.resetDemo();

      expect(app.otpSent, isFalse);
      expect(app.otpCode, isEmpty);
      expect(app.otpSentAt, isNull);
      expect(app.otpResendCount, 0);
    });
  });
}
