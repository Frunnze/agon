import 'dart:convert';

import '../../../bridge/support/scripted_node_transport.dart';
import 'simulated_work_node.dart';

const String simulatedWorkDeviceId = 'simulated-this-device';
const String _commandField = 'command';
const String _taskField = 'task';
const String _taskIdField = 'task_id';
const String _projectField = 'project_id';
const String _workspaceField = 'workspace_id';
const String _okField = 'ok';
const String _tasksField = 'tasks';
const String _statusField = 'status';
const Set<String> _savingCommands = <String>{
  'create_task',
  'update_task',
  'create_job',
  'update_job',
};
const Set<String> _unfinishedRunStatuses = <String>{
  'queued',
  'running',
  'waiting_for_approval',
};

final class SimulatedWorkspaceWorkNode {
  SimulatedWorkspaceWorkNode({required this.projectWorkspaces});

  final Map<String, String> projectWorkspaces;
  final SimulatedWorkNode work = SimulatedWorkNode(
    thisDeviceId: simulatedWorkDeviceId,
  );

  String answer(String inputJson) {
    final WireRecord command = jsonDecode(inputJson) as WireRecord;
    final String name = command[_commandField]! as String;
    final String? refusal = _describeRefusal(name, command);
    if (refusal != null) {
      return encodeErrorReply(refusal);
    }

    final String reply = work.answer(inputJson);
    return switch (name) {
      'list_tasks' => _keepTasksListedIn(reply, command[_workspaceField]),
      'list_jobs' => _keepJobsListedIn(reply, command[_workspaceField]),
      _ => reply,
    };
  }

  bool isInWorkspace(WireRecord view, Object? workspaceId) {
    final WireRecord task = view[_taskField]! as WireRecord;
    final String? projectWorkspace = projectWorkspaces[task[_projectField]];
    return projectWorkspace != null && projectWorkspace == workspaceId;
  }

  String? _describeRefusal(String name, WireRecord command) {
    if (_savingCommands.contains(name)) {
      return _describeUploadRefusal(command[_taskField]! as WireRecord);
    }
    if (name == 'start_task' && _isRunning(command[_taskIdField])) {
      return 'the app server answered 409: the task is already running';
    }
    return null;
  }

  String? _describeUploadRefusal(WireRecord arguments) {
    final String title = arguments['title']! as String;
    if (title.trim().isEmpty) {
      return 'the task title cannot be empty';
    }
    final Object? projectId = arguments[_projectField];
    final String? projectWorkspace = projectWorkspaces[projectId];
    if (projectWorkspace == null) {
      return 'project $projectId was not found';
    }
    final Object? workspaceId = arguments[_workspaceField];
    if (projectWorkspace != workspaceId) {
      return 'project $projectId is not part of workspace $workspaceId';
    }
    return null;
  }

  bool _isRunning(Object? taskId) {
    for (final WireRecord run in work.runs.values) {
      final bool isUnfinished = _unfinishedRunStatuses.contains(
        run[_statusField],
      );
      if (run[_taskIdField] == taskId && isUnfinished) {
        return true;
      }
    }
    return false;
  }

  String _keepTasksListedIn(String reply, Object? workspaceId) {
    final WireRecord decoded = jsonDecode(reply) as WireRecord;
    final WireRecord? listing = decoded[_okField] as WireRecord?;
    if (listing == null) {
      return reply;
    }
    final List<Object?> views = listing[_tasksField]! as List<Object?>;
    listing[_tasksField] = <Object?>[
      for (final Object? view in views)
        if (isInWorkspace(view! as WireRecord, workspaceId)) view,
    ];
    return encodeSuccessReply(listing);
  }

  String _keepJobsListedIn(String reply, Object? workspaceId) {
    final WireRecord decoded = jsonDecode(reply) as WireRecord;
    final List<Object?>? views = decoded[_okField] as List<Object?>?;
    if (views == null) {
      return reply;
    }
    return encodeSuccessReply(<Object?>[
      for (final Object? view in views)
        if (isInWorkspace(view! as WireRecord, workspaceId)) view,
    ]);
  }
}
