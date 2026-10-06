import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:labour_marketplace/backend/models.dart';
import 'package:labour_marketplace/data/catalog.dart';
import 'package:labour_marketplace/state/app_state.dart';

void main() {
  group('existing account with another role', () {
    test('a number already registered as client is not turned into a contractor', () {
      expect(
          AppState.existingRoleConflict(
              chosen: Role.contractor, storedRole: 'client'),
          Role.client);
    });

    test('same role, or no profile yet, is not a conflict', () {
      for (final r in Role.values) {
        expect(AppState.existingRoleConflict(chosen: r, storedRole: r.name),
            isNull);
        expect(AppState.existingRoleConflict(chosen: r, storedRole: null),
            isNull);
      }
    });
  });

  group('direct chat from Find', () {
    test('contractors and clients may start one, no application needed', () {
      for (final r in [Role.contractor, Role.client]) {
        expect(
            AppState.canStartDirectChat(
                myRole: r, myUid: 'c1', peerId: 'w1', peerBlocked: false),
            isTrue);
      }
    });

    test('other roles, self, placeholders and blocked peers are refused', () {
      for (final r in [Role.labourer, Role.vendor, null]) {
        expect(
            AppState.canStartDirectChat(
                myRole: r, myUid: 'u1', peerId: 'w1', peerBlocked: false),
            isFalse);
      }
      bool contractorTo(String peer, {bool blocked = false}) =>
          AppState.canStartDirectChat(
              myRole: Role.contractor,
              myUid: 'c1',
              peerId: peer,
              peerBlocked: blocked);
      expect(contractorTo('c1'), isFalse);
      expect(contractorTo('me'), isFalse);
      expect(contractorTo(''), isFalse);
      expect(contractorTo('w1', blocked: true), isFalse);
    });

    test('one stable thread id per pair, whoever opens it', () {
      expect(ThreadDoc.directIdFor('b', 'a'), 'direct_a_b');
      expect(ThreadDoc.directIdFor('a', 'b'), ThreadDoc.directIdFor('b', 'a'));
      expect(ThreadDoc.directIdFor('a', 'b'),
          isNot(ThreadDoc.idFor('a', 'b')));
    });
  });

  group('Gardener occupation', () {
    test('is a real unskilled skill with a default wage', () {
      final g = skillById('gardener');
      expect(g, isNotNull);
      expect(g!.wageCategory, 'unskilled');
      expect(g.name('hi'), 'माली');
      expect(g.name('pa'), 'ਮਾਲੀ');
      expect(kDefaultSkillWage['gardener'], isNotNull);
      expect(skillCategoryByDisplayName('Gardener'), 'unskilled');
    });

    test('every skill is known to the server minimum-wage check with the same category', () {
      final js = File('functions/min_wage.js').readAsStringSync();
      for (final s in kSkills) {
        expect(kDefaultSkillWage.containsKey(s.id), isTrue, reason: s.id);
        final entry = RegExp('"${RegExp.escape(s.displayName)}": "([a-z_]+)"')
            .firstMatch(js);
        expect(entry, isNotNull, reason: '${s.displayName} missing in min_wage.js');
        expect(entry!.group(1), s.wageCategory, reason: s.displayName);
      }
    });
  });
}
