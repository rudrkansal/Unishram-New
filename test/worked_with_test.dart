import 'package:flutter_test/flutter_test.dart';
import 'package:labour_marketplace/data/catalog.dart';
import 'package:labour_marketplace/state/app_state.dart';

Job _job({String status = 'open', DateTime? end}) => Job(
      id: 'j',
      title: 't',
      skill: 'Mason',
      area: '',
      location: '',
      distance: '',
      wage: 700,
      contractor: 'C',
      contractorPhone: '',
      postedAgo: '',
      duration: '',
      desc: '',
      status: status,
      endDate: end,
    );

void main() {
  final now = DateTime(2026, 10, 24, 12);

  test('a job is current while open or filled and not past its end date', () {
    expect(AppState.isJobCurrent(_job(), now), isTrue);
    expect(AppState.isJobCurrent(_job(status: 'filled', end: DateTime(2026, 10, 30)), now), isTrue);
    expect(AppState.isJobCurrent(_job(end: DateTime(2026, 10, 1)), now), isFalse);
    expect(AppState.isJobCurrent(_job(status: 'closed'), now), isFalse);
  });

  test('hired people always count; shortlisted only on a running job', () {
    expect(AppState.countsAsWorkedWith('hired', false), isTrue);
    expect(AppState.countsAsWorkedWith('hired', true), isTrue);
    expect(AppState.countsAsWorkedWith('shortlisted', true), isTrue);
    expect(AppState.countsAsWorkedWith('shortlisted', false), isFalse);
    expect(AppState.countsAsWorkedWith('pending', true), isFalse);
    expect(AppState.countsAsWorkedWith('rejected', true), isFalse);
  });
}
