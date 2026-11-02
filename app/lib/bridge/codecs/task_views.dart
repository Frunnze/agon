import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/run_progress_values.dart';
import 'package:agent_orchestration/bridge/codecs/task_values.dart';

final class TaskView implements JsonEncodable {
  const TaskView({
    required this.task,
    required this.projectName,
    required this.latestRun,
  });

  factory TaskView.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return TaskView(
      task: readField(fields, 'task', Task.fromJson),
      projectName: readField(fields, 'project_name', decodeText),
      latestRun: readOptionalField(fields, 'latest_run', RunProgress.fromJson),
    );
  }

  final Task task;
  final String projectName;
  final RunProgress? latestRun;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'task': task.toJson(),
      'project_name': projectName,
      'latest_run': latestRun?.toJson(),
    };
  }
}

final class TasksView implements JsonEncodable {
  TasksView({
    required this.summary,
    required this.summaryText,
    required List<TaskView> tasks,
  }) : tasks = List<TaskView>.unmodifiable(tasks);

  factory TasksView.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return TasksView(
      summary: readField(fields, 'summary', TaskSummary.fromJson),
      summaryText: readField(fields, 'summary_text', decodeText),
      tasks: readListField(fields, 'tasks', TaskView.fromJson),
    );
  }

  final TaskSummary summary;
  final String summaryText;
  final List<TaskView> tasks;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'summary': summary.toJson(),
      'summary_text': summaryText,
      'tasks': encodeList(tasks),
    };
  }
}

final class JobView implements JsonEncodable {
  const JobView({
    required this.task,
    required this.projectName,
    required this.scheduleDescription,
    required this.nextRunAt,
    required this.latestRun,
  });

  factory JobView.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return JobView(
      task: readField(fields, 'task', Task.fromJson),
      projectName: readField(fields, 'project_name', decodeText),
      scheduleDescription: readField(
        fields,
        'schedule_description',
        decodeText,
      ),
      nextRunAt: readField(fields, 'next_run_at', decodeMoment),
      latestRun: readOptionalField(fields, 'latest_run', RunProgress.fromJson),
    );
  }

  final Task task;
  final String projectName;
  final String scheduleDescription;
  final DateTime nextRunAt;
  final RunProgress? latestRun;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'task': task.toJson(),
      'project_name': projectName,
      'schedule_description': scheduleDescription,
      'next_run_at': encodeMoment(nextRunAt),
      'latest_run': latestRun?.toJson(),
    };
  }
}
