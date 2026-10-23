import 'package:flutter_test/flutter_test.dart';
import 'package:labour_marketplace/backend/models.dart';

void main() {
  final now = DateTime.now();

  group('ModerationDoc', () {
    test('a new warning is unread until acknowledged, and shows again for a newer notice', () {
      final notice = now.subtract(const Duration(hours: 1));
      expect(ModerationDoc(status: 'warned', noticeAt: notice).warningUnread, isTrue);
      expect(
          ModerationDoc(status: 'warned', noticeAt: notice, warningSeenAt: now).warningUnread,
          isFalse);
      expect(
          ModerationDoc(
                  status: 'warned',
                  noticeAt: now,
                  warningSeenAt: notice)
              .warningUnread,
          isTrue);
    });

    test('a pause or suspension locks the app; a warning does not', () {
      expect(const ModerationDoc(status: 'banned').locked, isTrue);
      expect(const ModerationDoc(status: 'suspended').locked, isTrue);
      expect(const ModerationDoc(status: 'warned').locked, isFalse);
      expect(const ModerationDoc().locked, isFalse);
      // The warning card never stacks on top of the pause screen.
      expect(ModerationDoc(status: 'banned', noticeAt: now).warningUnread, isFalse);
    });

    test('strikes older than 90 days stop counting', () {
      final m = ModerationDoc(status: 'warned', strikeTimes: [
        now.subtract(const Duration(days: 100)),
        now.subtract(const Duration(days: 10)),
      ]);
      expect(m.activeStrikes().length, 1);
      final expiry = m.nextStrikeExpiry!;
      expect(expiry.difference(now).inDays, inInclusiveRange(79, 80));
      expect(const ModerationDoc().nextStrikeExpiry, isNull);
    });
  });
}
