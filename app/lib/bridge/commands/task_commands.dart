import 'package:agent_orchestration/bridge/codecs/approval_values.dart';
import 'package:agent_orchestration/bridge/codecs/device_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/run_values.dart';
import 'package:agent_orchestration/bridge/codecs/schedule_values.dart';
import 'package:agent_orchestration/bridge/codecs/task_values.dart';
import 'package:agent_orchestration/bridge/codecs/task_views.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';
import 'package:agent_orchestration/bridge/node/runner_settings.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

final class TaskArguments implements JsonEncodable {
  TaskArguments({
    required this.workspaceId,
    required this.projectId,
    required this.title,
    required this.details,
    required this.doer,
    required this.runsOn,
    required this.agentPlace,
    required List<SkillId> skills,
    required this.usesAutomaticSkills,
    required this.approvalPolicy,
  }) : skills = List<SkillId>.unmodifiable(skills);

  final WorkspaceId workspaceId;
  final ProjectId projectId;
  final String title;
  final String details;
  final TaskDoer doer;
  final RunnerTarget runsOn;
  final AgentPlace agentPlace;
  final List<SkillId> skills;
  final bool usesAutomaticSkills;
  final ApprovalPolicy approvalPolicy;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'workspace_id': workspaceId.value,
      'project_id': projectId.value,
      'title': title,
      'details': details,
      'doer': doer.toJson(),
      'runs_on': runsOn.toJson(),
      'agent_place': agentPlace.wireName,
      'skills': skills,
      'uses_automatic_skills': usesAutomaticSkills,
      'approval_policy': approvalPolicy.wireName,
    };
  }
}

final class ListTasksCommand implements NodeCommand<TasksView> {
  const ListTasksCommand({required this.workspaceId});

  final WorkspaceId workspaceId;

  @override
  String get name => 'list_tasks';

  @override
  JsonObject get arguments {
    return <String, Object?>{'workspace_id': workspaceId.value};
  }

  @override
  TasksView decodeReply(Object? okValue) => TasksView.fromJson(okValue);
}

final class CreateTaskCommand implements NodeCommand<Task> {
  const CreateTaskCommand({required this.task, required this.start});

  final TaskArguments task;
  final TaskStart start;

  @override
  String get name => 'create_task';

  @override
  JsonObject get arguments {
    return <String, Object?>{'task': task.toJson(), 'start': start.wireName};
  }

  @override
  Task decodeReply(Object? okValue) => Task.fromJson(okValue);
}

final class UpdateTaskCommand implements NodeCommand<Task> {
  const UpdateTaskCommand({required this.taskId, required this.task});

  final TaskId taskId;
  final TaskArguments task;

  @override
  String get name => 'update_task';

  @override
  JsonObject get arguments {
    return <String, Object?>{'task_id': taskId.value, 'task': task.toJson()};
  }

  @override
  Task decodeReply(Object? okValue) => Task.fromJson(okValue);
}

final class ListJobsCommand implements NodeCommand<List<JobView>> {
  const ListJobsCommand({required this.workspaceId});

  final WorkspaceId workspaceId;

  @override
  String get name => 'list_jobs';

  @override
  JsonObject get arguments {
    return <String, Object?>{'workspace_id': workspaceId.value};
  }

  @override
  List<JobView> decodeReply(Object? okValue) {
    return decodeList(okValue, JobView.fromJson);
  }
}

final class CreateJobCommand implements NodeCommand<Task> {
  const CreateJobCommand({required this.task, required this.schedule});

  final TaskArguments task;
  final Schedule schedule;

  @override
  String get name => 'create_job';

  @override
  JsonObject get arguments {
    return <String, Object?>{
      'task': task.toJson(),
      'schedule': schedule.toJson(),
    };
  }

  @override
  Task decodeReply(Object? okValue) => Task.fromJson(okValue);
}

final class UpdateJobCommand implements NodeCommand<Task> {
  const UpdateJobCommand({
    required this.taskId,
    required this.task,
    required this.schedule,
  });

  final TaskId taskId;
  final TaskArguments task;
  final Schedule schedule;

  @override
  String get name => 'update_job';

  @override
  JsonObject get arguments {
    return <String, Object?>{
      'task_id': taskId.value,
      'task': task.toJson(),
      'schedule': schedule.toJson(),
    };
  }

  @override
  Task decodeReply(Object? okValue) => Task.fromJson(okValue);
}

final class StartTaskCommand implements NodeCommand<Run> {
  const StartTaskCommand({required this.taskId});

  final TaskId taskId;

  @override
  String get name => 'start_task';

  @override
  JsonObject get arguments => <String, Object?>{'task_id': taskId.value};

  @override
  Run decodeReply(Object? okValue) => Run.fromJson(okValue);
}
