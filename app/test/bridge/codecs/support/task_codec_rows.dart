import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/schedule_values.dart';
import 'package:agent_orchestration/bridge/codecs/task_values.dart';
import 'package:agent_orchestration/bridge/codecs/task_views.dart';

import '../../support/random_run_json.dart';
import '../../support/random_work_json.dart';
import 'codec_rows.dart';

const List<ConstructorRow> taskConstructorRows = <ConstructorRow>[
  ConstructorRow(encodable: taskDoerRow, rebuild: _rebuildTaskDoer),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'one_agent',
      buildJson: randomOneAgentJson,
      decode: TaskDoer.fromJson,
    ),
    rebuild: _rebuildTaskDoer,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'workflow_doer',
      buildJson: randomWorkflowDoerJson,
      decode: TaskDoer.fromJson,
    ),
    rebuild: _rebuildTaskDoer,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'task_summary',
      buildJson: randomTaskSummaryJson,
      decode: TaskSummary.fromJson,
    ),
    rebuild: _rebuildTaskSummary,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'task_view',
      buildJson: randomTaskViewJson,
      decode: TaskView.fromJson,
    ),
    rebuild: _rebuildTaskView,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'job_view',
      buildJson: randomJobViewJson,
      decode: JobView.fromJson,
    ),
    rebuild: _rebuildJobView,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'schedule_time',
      buildJson: randomScheduleTimeJson,
      decode: ScheduleTime.fromJson,
    ),
    rebuild: _rebuildScheduleTime,
  ),
  ConstructorRow(encodable: scheduleRow, rebuild: _rebuildSchedule),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'every_hour',
      buildJson: randomEveryHourJson,
      decode: Schedule.fromJson,
    ),
    rebuild: _rebuildSchedule,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'every_day',
      buildJson: randomEveryDayJson,
      decode: Schedule.fromJson,
    ),
    rebuild: _rebuildSchedule,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'every_week',
      buildJson: randomEveryWeekJson,
      decode: Schedule.fromJson,
    ),
    rebuild: _rebuildSchedule,
  ),
];

const EncodableRow taskDoerRow = EncodableRow(
  typeName: 'task_doer',
  buildJson: randomTaskDoerJson,
  decode: TaskDoer.fromJson,
);

const EncodableRow scheduleRow = EncodableRow(
  typeName: 'schedule',
  buildJson: randomScheduleJson,
  decode: Schedule.fromJson,
);

const List<EncodableRow> taskEncodableRows = <EncodableRow>[
  EncodableRow(
    typeName: 'task',
    buildJson: randomTaskJson,
    decode: Task.fromJson,
  ),
  EncodableRow(
    typeName: 'tasks_view',
    buildJson: randomTasksViewJson,
    decode: TasksView.fromJson,
  ),
];

Object? randomOneAgentJson(Random random) {
  return randomJsonOfKind<OneAgent>(
    random: random,
    buildJson: randomTaskDoerJson,
    decode: TaskDoer.fromJson,
  );
}

Object? randomWorkflowDoerJson(Random random) {
  return randomJsonOfKind<WorkflowDoer>(
    random: random,
    buildJson: randomTaskDoerJson,
    decode: TaskDoer.fromJson,
  );
}

Object? randomEveryHourJson(Random random) {
  return randomJsonOfKind<EveryHour>(
    random: random,
    buildJson: randomScheduleJson,
    decode: Schedule.fromJson,
  );
}

Object? randomEveryDayJson(Random random) {
  return randomJsonOfKind<EveryDay>(
    random: random,
    buildJson: randomScheduleJson,
    decode: Schedule.fromJson,
  );
}

Object? randomEveryWeekJson(Random random) {
  return randomJsonOfKind<EveryWeek>(
    random: random,
    buildJson: randomScheduleJson,
    decode: Schedule.fromJson,
  );
}

JsonEncodable _rebuildTaskDoer(JsonEncodable value) {
  final TaskDoer doer = value as TaskDoer;
  return switch (doer) {
    OneAgent(:final agent) => OneAgent(agent: agent),
    WorkflowDoer(:final workflowId) => WorkflowDoer(workflowId: workflowId),
  };
}

JsonEncodable _rebuildTaskSummary(JsonEncodable value) {
  final TaskSummary summary = value as TaskSummary;
  return TaskSummary(
    toDo: summary.toDo,
    running: summary.running,
    waitingForApproval: summary.waitingForApproval,
    failed: summary.failed,
    done: summary.done,
  );
}

JsonEncodable _rebuildTaskView(JsonEncodable value) {
  final TaskView view = value as TaskView;
  return TaskView(
    task: view.task,
    projectName: view.projectName,
    latestRun: view.latestRun,
  );
}

JsonEncodable _rebuildJobView(JsonEncodable value) {
  final JobView view = value as JobView;
  return JobView(
    task: view.task,
    projectName: view.projectName,
    scheduleDescription: view.scheduleDescription,
    nextRunAt: view.nextRunAt,
    latestRun: view.latestRun,
  );
}

JsonEncodable _rebuildScheduleTime(JsonEncodable value) {
  final ScheduleTime time = value as ScheduleTime;
  return ScheduleTime(hour: time.hour, minute: time.minute);
}

JsonEncodable _rebuildSchedule(JsonEncodable value) {
  final Schedule schedule = value as Schedule;
  return switch (schedule) {
    EveryHour(:final minute) => EveryHour(minute: minute),
    EveryDay(:final at) => EveryDay(at: at),
    EveryWeek(:final on, :final at) => EveryWeek(on: on, at: at),
  };
}
