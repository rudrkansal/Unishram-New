import 'package:flutter_test/flutter_test.dart';
import 'package:labour_marketplace/state/app_state.dart';

void main() {
  group('self-chat guard', () {
    test('a peer id equal to my own uid is a self chat', () {
      expect(AppState.isSelfChat('uid-1', 'uid-1'), isTrue);
    });

    test('a job I posted (contractorUid == my uid) is a self chat', () {
      const myUid = 'poster-uid';
      const jobContractorUid = 'poster-uid';
      expect(AppState.isSelfChat(jobContractorUid, myUid), isTrue);
    });

    test('a different user is allowed', () {
      expect(AppState.isSelfChat('uid-2', 'uid-1'), isFalse);
    });

    test('signed out / missing ids never count as self', () {
      expect(AppState.isSelfChat('uid-1', null), isFalse);
      expect(AppState.isSelfChat(null, 'uid-1'), isFalse);
      expect(AppState.isSelfChat(null, null), isFalse);
    });
  });
}
