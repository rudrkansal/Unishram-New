import 'package:flutter_test/flutter_test.dart';
import 'package:labour_marketplace/backend/adapters.dart';
import 'package:labour_marketplace/backend/models.dart';
import 'package:labour_marketplace/state/app_state.dart';

// Chat is job-scoped (firestore.rules require a jobId + application). These tests
// pin the app-side behaviour so a user can never land in a fake, non-delivering chat.
void main() {
  group('live chat may only be opened inside a job relationship', () {
    test('valid: signed in, real peer, a job', () {
      expect(AppState.canOpenLiveChat(peerId: 'peer', myUid: 'me1', jobId: 'job1'),
          isTrue);
    });

    test('direct (job-less) chat is refused', () {
      expect(AppState.canOpenLiveChat(peerId: 'peer', myUid: 'me1', jobId: null),
          isFalse);
      expect(AppState.canOpenLiveChat(peerId: 'peer', myUid: 'me1', jobId: ''),
          isFalse);
    });

    test("the 'me' placeholder, empty and self peers are refused", () {
      expect(AppState.canOpenLiveChat(peerId: 'me', myUid: 'me1', jobId: 'j'),
          isFalse);
      expect(AppState.canOpenLiveChat(peerId: '', myUid: 'me1', jobId: 'j'),
          isFalse);
      expect(AppState.canOpenLiveChat(peerId: null, myUid: 'me1', jobId: 'j'),
          isFalse);
      expect(AppState.canOpenLiveChat(peerId: 'me1', myUid: 'me1', jobId: 'j'),
          isFalse);
    });

    test('signed out is refused', () {
      expect(AppState.canOpenLiveChat(peerId: 'peer', myUid: null, jobId: 'j'),
          isFalse);
    });
  });

  group('a signed-in user never gets the local-only fake chat', () {
    test('no server thread while signed in -> blocked, not localDemo', () {
      expect(AppState.chatSendMode(liveBackend: true, hasThread: false),
          ChatSendMode.blocked);
    });

    test('server thread -> live', () {
      expect(AppState.chatSendMode(liveBackend: true, hasThread: true),
          ChatSendMode.live);
    });

    test('only the offline demo (no backend) may use the local sample chat', () {
      expect(AppState.chatSendMode(liveBackend: false, hasThread: false),
          ChatSendMode.localDemo);
      expect(AppState.chatSendMode(liveBackend: false, hasThread: true),
          ChatSendMode.localDemo);
    });

    test('every signed-in combination avoids localDemo', () {
      for (final hasThread in [true, false]) {
        expect(AppState.chatSendMode(liveBackend: true, hasThread: hasThread),
            isNot(ChatSendMode.localDemo));
      }
    });
  });

  group('Contact card only offers Send message for job-bound chats', () {
    test('Find-screen style card (no job) cannot chat', () {
      const card = ContactTarget(
          name: 'A', subtitle: 's', phone: '', chatPeerId: 'peer-uid');
      expect(card.canChat, isFalse);
    });

    test('card without a peer cannot chat even with a job', () {
      const card =
          ContactTarget(name: 'A', subtitle: 's', phone: '', chatJobId: 'job1');
      expect(card.canChat, isFalse);
    });

    test('job-bound card (job detail / applications) can chat', () {
      const card = ContactTarget(
          name: 'A',
          subtitle: 's',
          phone: '',
          chatJobId: 'job1',
          chatPeerId: 'contractor-uid');
      expect(card.canChat, isTrue);
    });

    test('empty ids never count', () {
      const card = ContactTarget(
          name: 'A', subtitle: 's', phone: '', chatJobId: '', chatPeerId: '');
      expect(card.canChat, isFalse);
    });
  });

  group("other users' phone numbers are not surfaced from public profiles", () {
    test('worker card from a profile that still carries a legacy phone shows none',
        () {
      const doc = UserDoc(uid: 'w1', role: 'labourer', fullName: 'W', phone: '+919999900000');
      expect(doc.toWorker().phone, '');
    });

    test('contractor card from a profile with a legacy phone shows none', () {
      const doc = UserDoc(uid: 'c1', role: 'contractor', fullName: 'C', phone: '+919999900000');
      expect(doc.toContractor().phone, '');
    });
  });
}
