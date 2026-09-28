import 'package:flutter_test/flutter_test.dart';
import 'package:labour_marketplace/state/app_state.dart';

void main() {
  group('when a labourer may see a contractor\'s phone number', () {
    test('an approved application unlocks contact', () {
      expect(AppState.isApprovedStatus('shortlisted'), isTrue);
      expect(AppState.isApprovedStatus('hired'), isTrue);
    });

    test('everything else keeps contact hidden — messaging stays open', () {
      expect(AppState.isApprovedStatus('pending'), isFalse);
      expect(AppState.isApprovedStatus('rejected'), isFalse);
      expect(AppState.isApprovedStatus('withdrawn'), isFalse);
      expect(AppState.isApprovedStatus(''), isFalse);
    });
  });
}
