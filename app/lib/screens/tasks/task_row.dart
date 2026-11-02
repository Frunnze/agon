import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/run_text.dart';
import 'package:agent_orchestration/presentation/runner_target_text.dart';
import 'package:agent_orchestration/presentation/time_phrases.dart';
import 'package:agent_orchestration/screens/shared/status_labels.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';
import 'package:agent_orchestration/widgets/lists/list_row_main.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

const String _notStartedYet = 'Not yet';
const String _subtitleSeparator = ' · ';

List<TextSegment> describeTaskRunsOn({
  required Task task,
  required Run? latestRun,
  required DeviceNames deviceNames,
}) {
  final DeviceId? runner = latestRun == null
      ? null
      : findCurrentStep(latestRun).runner;
  if (runner != null) {
    return <TextSegment>[TextSegment.monospace(deviceNames.nameOf(runner))];
  }
  return describeRunnerTarget(task.runsOn, deviceNames);
}

String describeTaskSubtitle({
  required String projectName,
  required String doerLabel,
  required Run? latestRun,
}) {
  final String? progress = latestRun == null
      ? null
      : describeStepProgress(latestRun);

  final List<String> parts = <String>[projectName, doerLabel];
  if (progress != null) {
    parts.add(progress);
  }

  return parts.join(_subtitleSeparator);
}

ListRowData buildTaskRow({
  required Task task,
  required Run? latestRun,
  required String projectName,
  required String doerLabel,
  required DeviceNames deviceNames,
  required DateTime now,
  required VoidCallback onTap,
}) {
  final String started = latestRun == null
      ? _notStartedYet
      : describeTimeSince(latestRun.startedAt, now);

  return ListRowData(
    key: ValueKey<TaskId>(task.id),
    main: ListRowMain(
      title: task.title,
      subtitle: <TextSegment>[
        TextSegment(
          describeTaskSubtitle(
            projectName: projectName,
            doerLabel: doerLabel,
            latestRun: latestRun,
          ),
        ),
      ],
    ),
    meta: <Widget>[
      MixedText(
        describeTaskRunsOn(
          task: task,
          latestRun: latestRun,
          deviceNames: deviceNames,
        ),
      ),
      Text(started),
    ],
    end: buildTaskStatusLabel(task.status),
    onTap: onTap,
  );
}
