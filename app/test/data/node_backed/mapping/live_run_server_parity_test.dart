import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/live_run_values.dart'
    as node;
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import 'support/shared_live_run_cases.dart';

const int _smallestSharedCaseCount = 32;

List<PostedRunEvent> _listDeliveredEvents(SharedLiveRunCase sharedCase) {
  return <PostedRunEvent>[
    for (final PostedRunEvent posted in sharedCase.events)
      if (posted.isAccepted) posted,
  ];
}

Run _applyEventByEvent(SharedLiveRunCase sharedCase) {
  Run run = sharedCase.initialRun;
  for (final PostedRunEvent posted in _listDeliveredEvents(sharedCase)) {
    run = applyLiveRunView(
      run: run,
      view: buildViewKeepingLink(run, <node.RunEvent>[posted.event]),
      at: posted.postedAt,
    );
  }
  return run;
}

List<List<PostedRunEvent>> _groupByMoment(List<PostedRunEvent> events) {
  final List<List<PostedRunEvent>> groups = <List<PostedRunEvent>>[];
  for (final PostedRunEvent posted in events) {
    final bool joinsLastGroup =
        groups.isNotEmpty && groups.last.first.postedAt == posted.postedAt;
    if (joinsLastGroup) {
      groups.last.add(posted);
    } else {
      groups.add(<PostedRunEvent>[posted]);
    }
  }
  return groups;
}

void main() {
  final List<SharedLiveRunCase> sharedCases = readSharedLiveRunCases();

  test(
    'test_apply_live_run_view_property_matches_the_server_event_by_event',
    () {
      expect(
        sharedCases.length,
        greaterThanOrEqualTo(_smallestSharedCaseCount),
      );

      for (final SharedLiveRunCase sharedCase in sharedCases) {
        final Run applied = _applyEventByEvent(sharedCase);

        expect(
          describeWholeRun(applied),
          describeWholeRun(sharedCase.expectedRun),
        );
      }
    },
  );

  test('test_apply_live_run_view_property_matches_the_server_per_moment', () {
    for (final SharedLiveRunCase sharedCase in sharedCases) {
      Run run = sharedCase.initialRun;
      for (final List<PostedRunEvent> group in _groupByMoment(
        _listDeliveredEvents(sharedCase),
      )) {
        final List<node.RunEvent> events = <node.RunEvent>[
          for (final PostedRunEvent posted in group) posted.event,
        ];
        run = applyLiveRunView(
          run: run,
          view: buildViewKeepingLink(run, events),
          at: group.first.postedAt,
        );
      }

      expect(describeWholeRun(run), describeWholeRun(sharedCase.expectedRun));
    }
  });

  test(
    'test_apply_live_run_view_property_redelivered_records_change_nothing',
    () {
      for (final SharedLiveRunCase sharedCase in sharedCases) {
        final Run expected = sharedCase.expectedRun;
        final List<node.RunEvent> recordEvents = <node.RunEvent>[
          for (final PostedRunEvent posted in _listDeliveredEvents(sharedCase))
            if (posted.event is node.LogAppended ||
                posted.event is node.ChatAppended)
              posted.event,
        ];

        final Run redelivered = applyLiveRunView(
          run: expected,
          view: buildViewKeepingLink(expected, recordEvents),
          at: sharedCase.events.last.postedAt,
        );

        expect(describeWholeRun(redelivered), describeWholeRun(expected));
      }
    },
  );
}
