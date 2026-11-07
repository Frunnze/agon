import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/live_run_values.dart'
    as node;
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../../bridge/support/random_live_json.dart';
import '../../../support/random_inputs.dart';
import '../../models/support/random_run_records.dart';
import 'support/live_run_views.dart';

LogLine _newLogLine(Random random, int index) {
  final LogLine line = randomLogLine(random);
  return LogLine(
    at: line.at,
    stepName: line.stepName,
    text: '${line.text}$newRecordMark$index',
    isError: line.isError,
  );
}

LogLine _logLineVariant(Random random, LogLine line) {
  return switch (random.nextInt(3)) {
    0 => LogLine(
      at: line.at,
      stepName: line.stepName,
      text: '${line.text}$newRecordMark',
      isError: line.isError,
    ),
    1 => LogLine(
      at: line.at.add(oneMicrosecond),
      stepName: line.stepName,
      text: line.text,
      isError: line.isError,
    ),
    _ => LogLine(
      at: line.at,
      stepName: '${line.stepName}$newRecordMark',
      text: line.text,
      isError: line.isError,
    ),
  };
}

final DateTime _appliedAt = DateTime.utc(2026, 11, 7, 9, 30);

void main() {
  test('test_is_same_log_line_property_redelivered_line_is_not_repeated', () {
    final Random random = seededRandom(72101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = randomLiveRunWithRecords(random);
      final List<node.RunEvent> events = <node.RunEvent>[
        for (final LogLine line in run.log) buildLogEvent(line),
      ];

      final Run applied = applyLiveRunView(
        run: run,
        view: buildLiveView(events),
        at: _appliedAt,
      );

      expect(describeLog(applied.log), describeLog(run.log));
    }
  });

  test('test_is_same_log_line_property_changed_line_is_a_new_line', () {
    final Random random = seededRandom(72102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = randomLiveRunWithRecords(random);
      final LogLine variant = _logLineVariant(
        random,
        pickOne(random, run.log),
      );

      final Run applied = applyLiveRunView(
        run: run,
        view: buildLiveView(<node.RunEvent>[buildLogEvent(variant)]),
        at: _appliedAt,
      );

      expect(
        describeLog(applied.log),
        describeLog(<LogLine>[...run.log, variant]),
      );
    }
  });

  test('test_is_same_log_line_property_matches_only_identical_lines', () {
    final Random random = seededRandom(72103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = randomLiveRunWithRecords(random);
      final LogLine existing = pickOne(random, run.log);
      final LogLine variant = _logLineVariant(random, existing);

      final Run applied = applyLiveRunView(
        run: run,
        view: buildLiveView(<node.RunEvent>[
          buildLogEvent(variant),
          buildLogEvent(existing),
          buildLogEvent(variant),
        ]),
        at: _appliedAt,
      );

      expect(applied.log.length, run.log.length + 1);
      expect(
        describeLog(<LogLine>[applied.log.last]),
        describeLog(<LogLine>[variant]),
      );
    }
  });

  test('test_append_log_line_property_new_lines_land_at_the_end_in_order', () {
    final Random random = seededRandom(72107);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = randomLiveRun(random);
      final int newLineCount = random.nextInt(largestNewRecordCount);
      final List<LogLine> newLines = <LogLine>[
        for (int index = 0; index < newLineCount; index += 1)
          _newLogLine(random, index),
      ];

      final Run applied = applyLiveRunView(
        run: run,
        view: buildLiveView(<node.RunEvent>[
          for (final LogLine line in newLines) buildLogEvent(line),
        ]),
        at: _appliedAt,
      );

      expect(
        describeLog(applied.log),
        describeLog(<LogLine>[...run.log, ...newLines]),
      );
    }
  });

  test('test_append_log_line_property_repeats_in_one_view_land_once', () {
    final Random random = seededRandom(72108);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = randomLiveRun(random);
      final int newLineCount = random.nextInt(largestNewRecordCount);
      final List<node.RunEvent> events = <node.RunEvent>[
        for (int index = 0; index < newLineCount; index += 1)
          buildLogEvent(_newLogLine(random, index)),
      ];

      final Run once = applyLiveRunView(
        run: run,
        view: buildLiveView(events),
        at: _appliedAt,
      );
      final Run repeated = applyLiveRunView(
        run: run,
        view: buildLiveView(<node.RunEvent>[...events, ...events]),
        at: _appliedAt,
      );

      expect(describeLog(repeated.log), describeLog(once.log));
    }
  });

  test('test_append_log_line_property_other_events_leave_the_log_alone', () {
    final Random random = seededRandom(72109);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = randomLiveRun(random);
      final node.WatchView view = node.WatchView.fromJson(
        randomWatchViewJson(random),
      );
      final List<node.RunEvent> logEvents = <node.RunEvent>[
        ...view.events.whereType<node.LogAppended>(),
      ];

      final Run applied = applyLiveRunView(
        run: run,
        view: view,
        at: _appliedAt,
      );
      final Run onlyLog = applyLiveRunView(
        run: run,
        view: buildLiveView(logEvents),
        at: _appliedAt,
      );

      expect(describeLog(applied.log), describeLog(onlyLog.log));
    }
  });
}
