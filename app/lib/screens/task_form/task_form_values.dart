import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/schedule_rules.dart';

const String defaultScheduleTimeText = '09:00';
const TaskDoer defaultTaskDoer = OneAgentDoer(AgentKind.claudeCode);
const int _hourlyRunMinute = 0;

RepeatChoice _findRepeatChoice(Schedule? schedule) {
  switch (schedule) {
    case null:
      return RepeatChoice.none;
    case HourlySchedule():
      return RepeatChoice.hourly;
    case DailySchedule():
      return RepeatChoice.daily;
    case WeeklySchedule():
      return RepeatChoice.weekly;
  }
}

Weekday _findWeekday(Schedule? schedule) {
  if (schedule is WeeklySchedule) {
    return schedule.on;
  }
  return Weekday.monday;
}

String _findTimeText(Schedule? schedule) {
  if (schedule is DailySchedule) {
    return formatScheduleTime(schedule.at);
  }
  if (schedule is WeeklySchedule) {
    return formatScheduleTime(schedule.at);
  }
  return defaultScheduleTimeText;
}

enum RepeatChoice {
  none("Don't repeat"),
  hourly('Every hour'),
  daily('Every day'),
  weekly('Every week');

  const RepeatChoice(this.label);

  final String label;

  bool get needsTime => this == daily || this == weekly;
}

final class TaskFormValues {
  TaskFormValues({
    required this.title,
    required this.details,
    required this.projectId,
    required this.doer,
    required this.runsOn,
    required List<SkillId> skillIds,
    required this.usesAutomaticSkills,
    required this.approvalPolicy,
    required this.repeat,
    required this.weekday,
    required this.timeText,
  }) : skillIds = List<SkillId>.unmodifiable(skillIds);

  factory TaskFormValues.blank({
    required ProjectId projectId,
    required TaskDoer doer,
    required RepeatChoice repeat,
  }) {
    return TaskFormValues(
      title: '',
      details: '',
      projectId: projectId,
      doer: doer,
      runsOn: const AnyFreeRunner(),
      skillIds: const <SkillId>[],
      usesAutomaticSkills: true,
      approvalPolicy: ApprovalPolicy.askBeforeRiskyActions,
      repeat: repeat,
      weekday: Weekday.monday,
      timeText: defaultScheduleTimeText,
    );
  }

  factory TaskFormValues.fromTask(Task task) {
    final Schedule? schedule = task.schedule;

    return TaskFormValues(
      title: task.title,
      details: task.details,
      projectId: task.projectId,
      doer: task.doer,
      runsOn: task.runsOn,
      skillIds: task.skills,
      usesAutomaticSkills: task.usesAutomaticSkills,
      approvalPolicy: task.approvalPolicy,
      repeat: _findRepeatChoice(schedule),
      weekday: _findWeekday(schedule),
      timeText: _findTimeText(schedule),
    );
  }

  final String title;
  final String details;
  final ProjectId projectId;
  final TaskDoer doer;
  final RunnerTarget runsOn;
  final List<SkillId> skillIds;
  final bool usesAutomaticSkills;
  final ApprovalPolicy approvalPolicy;
  final RepeatChoice repeat;
  final Weekday weekday;
  final String timeText;

  TaskFormValues copyWith({
    String? title,
    String? details,
    ProjectId? projectId,
    TaskDoer? doer,
    RunnerTarget? runsOn,
    List<SkillId>? skillIds,
    bool? usesAutomaticSkills,
    ApprovalPolicy? approvalPolicy,
    RepeatChoice? repeat,
    Weekday? weekday,
    String? timeText,
  }) {
    return TaskFormValues(
      title: title ?? this.title,
      details: details ?? this.details,
      projectId: projectId ?? this.projectId,
      doer: doer ?? this.doer,
      runsOn: runsOn ?? this.runsOn,
      skillIds: skillIds ?? this.skillIds,
      usesAutomaticSkills: usesAutomaticSkills ?? this.usesAutomaticSkills,
      approvalPolicy: approvalPolicy ?? this.approvalPolicy,
      repeat: repeat ?? this.repeat,
      weekday: weekday ?? this.weekday,
      timeText: timeText ?? this.timeText,
    );
  }

  String? describeTitleProblem() {
    if (title.trim().isEmpty) {
      return 'Write what should be done.';
    }
    return null;
  }

  String? describeTimeProblem() {
    if (repeat.needsTime && parseScheduleTime(timeText) == null) {
      return 'Write the time as HH:MM, for example 09:00.';
    }
    return null;
  }

  bool get isValid {
    return describeTitleProblem() == null && describeTimeProblem() == null;
  }

  TaskDraft toTaskDraft() {
    return TaskDraft(
      title: title.trim(),
      details: details.trim(),
      projectId: projectId,
      doer: doer,
      runsOn: runsOn,
      skills: skillIds,
      usesAutomaticSkills: usesAutomaticSkills,
      approvalPolicy: approvalPolicy,
    );
  }

  Schedule? toSchedule() {
    switch (repeat) {
      case RepeatChoice.none:
        return null;
      case RepeatChoice.hourly:
        return HourlySchedule(minute: _hourlyRunMinute);
      case RepeatChoice.daily:
        return DailySchedule(at: _requireScheduleTime());
      case RepeatChoice.weekly:
        return WeeklySchedule(on: weekday, at: _requireScheduleTime());
    }
  }

  ScheduleTime _requireScheduleTime() {
    final ScheduleTime? time = parseScheduleTime(timeText);
    if (time == null) {
      throw FormatException('Not a time of day', timeText);
    }
    return time;
  }
}
