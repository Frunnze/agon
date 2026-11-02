import 'dart:convert';
import 'dart:math';

import '../../../bridge/support/node_wire_names.dart';
import '../../../bridge/support/random_run_json.dart';
import '../../../bridge/support/random_work_json.dart';
import '../../../bridge/support/scripted_node_transport.dart';
import '../../../support/random_inputs.dart';
import 'simulated_deletions.dart';

typedef WireRecord = Map<String, Object?>;

const String simulatedProjectName = 'website';
const String simulatedMoment = '2026-10-31T09:00:00.000Z';
const String _identifierPrefix = 'simulated-';
const String _scheduleField = 'schedule';
const String _statusField = 'status';
const String _chatField = 'chat';
const Map<String, String> _taskStatusForRunStatus = <String, String>{
  'queued': 'running',
  'running': 'running',
  'waiting_for_approval': 'waiting_for_approval',
  'failed': 'failed',
  'cancelled': 'to_do',
  'done': 'done',
};

final class SimulatedRefusal implements Exception {
  const SimulatedRefusal(this.message);

  final String message;
}

bool isJob(WireRecord task) => task[_scheduleField] != null;

final class SimulatedWorkNode {
  SimulatedWorkNode({required this.thisDeviceId});

  final String thisDeviceId;
  final Map<String, WireRecord> tasks = <String, WireRecord>{};
  final Map<String, WireRecord> runs = <String, WireRecord>{};
  final Map<String, List<WireRecord>> liveEvents =
      <String, List<WireRecord>>{};
  final Map<String, String> liveLinks = <String, String>{};
  final List<String> stoppedRuns = <String>[];
  final List<String> receivedCommands = <String>[];
  String? refusal;
  int _createdCount = 0;

  String answer(String inputJson) {
    final WireRecord command = jsonDecode(inputJson) as WireRecord;
    final String name = command['command']! as String;
    receivedCommands.add(name);
    final String? currentRefusal = refusal;
    if (currentRefusal != null) {
      return encodeErrorReply(currentRefusal);
    }
    try {
      return encodeSuccessReply(_answerCommand(name, command));
    } on SimulatedRefusal catch (refused) {
      return encodeErrorReply(refused.message);
    }
  }

  String addTaskFromElsewhere(Random random) {
    final WireRecord task = randomTaskJson(random);
    final String taskId = _nextIdentifier();
    task['id'] = taskId;
    tasks[taskId] = task;
    return taskId;
  }

  String addRunFromElsewhere(Random random, String taskId) {
    final WireRecord run = randomRunJson(random);
    final String runId = _nextIdentifier();
    run['id'] = runId;
    run['task_id'] = taskId;
    runs[runId] = run;
    _followRunStatus(run);
    return runId;
  }

  void changeRunFromElsewhere(Random random, String runId) {
    final WireRecord run = _findRecord(runs, runId);
    run[_statusField] = pickOne(random, nodeRunStatuses);
    (run[_chatField]! as List<Object?>).add(randomChatMessageJson(random));
    _followRunStatus(run);
  }

  Object? _answerCommand(String name, WireRecord command) {
    return switch (name) {
      'list_tasks' => _listTasks(),
      'list_jobs' => _listJobs(),
      'create_task' => _createTask(command['task']! as WireRecord, null),
      'create_job' => _createTask(
        command['task']! as WireRecord,
        command[_scheduleField],
      ),
      'update_task' => _updateTask(command, null),
      'update_job' => _updateTask(command, command[_scheduleField]),
      'start_task' => _startTask(command['task_id']! as String),
      'list_runs' => _listRuns(command['task_id']! as String),
      'show_run' => _showRun(command['run_id']! as String),
      'cancel_run' => _changeRunStatus(
        command['run_id']! as String,
        'cancelled',
      ),
      'retry_run' => _changeRunStatus(command['run_id']! as String, 'queued'),
      'send_chat_message' => _sendChatMessage(command),
      'watch_run' => _watchRun(command['run_id']! as String),
      'stop_watching_run' => _stopWatchingRun(command['run_id']! as String),
      'delete_task' => deleteSimulatedTask(
        tasks: tasks,
        runs: runs,
        taskId: command['task_id']! as String,
      ),
      _ => throw SimulatedRefusal('unknown command: $name'),
    };
  }

  WireRecord _listTasks() {
    final List<Object?> views = <Object?>[
      for (final WireRecord task in tasks.values)
        if (!isJob(task))
          <String, Object?>{
            'task': task,
            'project_name': simulatedProjectName,
            'latest_run': null,
          },
    ];
    return <String, Object?>{
      'summary': <String, Object?>{
        'to_do': 0,
        'running': 0,
        'waiting_for_approval': 0,
        'failed': 0,
        'done': 0,
      },
      'summary_text': '',
      'tasks': views,
    };
  }

  List<Object?> _listJobs() {
    return <Object?>[
      for (final WireRecord task in tasks.values)
        if (isJob(task))
          <String, Object?>{
            'task': task,
            'project_name': simulatedProjectName,
            'schedule_description': '',
            'next_run_at': simulatedMoment,
            'latest_run': null,
          },
    ];
  }

  WireRecord _createTask(WireRecord arguments, Object? schedule) {
    final WireRecord task = Map<String, Object?>.of(arguments);
    final String taskId = _nextIdentifier();
    task.remove('workspace_id');
    task['id'] = taskId;
    task[_scheduleField] = schedule;
    task[_statusField] = 'to_do';
    task['created_at'] = simulatedMoment;
    tasks[taskId] = task;
    return task;
  }

  WireRecord _updateTask(WireRecord command, Object? schedule) {
    final String taskId = command['task_id']! as String;
    final WireRecord existing = _findRecord(tasks, taskId);
    final WireRecord task = Map<String, Object?>.of(
      command['task']! as WireRecord,
    );
    task.remove('workspace_id');
    task['id'] = taskId;
    task[_scheduleField] = schedule;
    task[_statusField] = existing[_statusField];
    task['created_at'] = existing['created_at'];
    tasks[taskId] = task;
    return task;
  }

  WireRecord _startTask(String taskId) {
    _findRecord(tasks, taskId);
    final String runId = _nextIdentifier();
    final WireRecord run = <String, Object?>{
      'id': runId,
      'task_id': taskId,
      'number': _listRuns(taskId).length + 1,
      _statusField: 'queued',
      'steps': <Object?>[],
      'log': <Object?>[],
      _chatField: <Object?>[],
      'failure': null,
      'link': 'direct',
      'link_lost_at': null,
      'agent_session': null,
      'worktree_branch': null,
      'started_by': thisDeviceId,
      'started_at': simulatedMoment,
      'finished_at': null,
    };
    runs[runId] = run;
    _followRunStatus(run);
    return run;
  }

  List<Object?> _listRuns(String taskId) {
    return <Object?>[
      for (final WireRecord run in runs.values)
        if (run['task_id'] == taskId) run,
    ];
  }

  WireRecord _showRun(String runId) {
    final WireRecord run = _findRecord(runs, runId);
    return <String, Object?>{
      'run': run,
      'progress': <String, Object?>{
        'run_id': runId,
        'number': run['number'],
        _statusField: run[_statusField],
        'link': run['link'],
        'started_at': run['started_at'],
        'finished_at': run['finished_at'],
        'step_count': 0,
        'current_step': null,
      },
      'link': run['link'],
      'link_lost_at': run['link_lost_at'],
    };
  }

  Object? _changeRunStatus(String runId, String status) {
    final WireRecord run = _findRecord(runs, runId);
    run[_statusField] = status;
    _followRunStatus(run);
    return null;
  }

  WireRecord _watchRun(String runId) {
    final List<WireRecord> events = liveEvents.remove(runId) ?? <WireRecord>[];
    return <String, Object?>{
      'link': liveLinks[runId] ?? 'unreachable',
      'link_lost_at': null,
      'problem': null,
      'events': events,
    };
  }

  Object? _stopWatchingRun(String runId) {
    stoppedRuns.add(runId);
    return null;
  }

  WireRecord _sendChatMessage(WireRecord command) {
    final WireRecord run = _findRecord(runs, command['run_id']! as String);
    final WireRecord message = <String, Object?>{
      'at': simulatedMoment,
      'author': 'you',
      'text': command['text'],
      'is_error': false,
      'waiting_to_send': false,
    };
    (run[_chatField]! as List<Object?>).add(message);
    return message;
  }

  void _followRunStatus(WireRecord run) {
    final WireRecord? task = tasks[run['task_id']];
    if (task == null) {
      return;
    }
    task[_statusField] = _taskStatusForRunStatus[run[_statusField]];
  }

  WireRecord _findRecord(Map<String, WireRecord> records, String identifier) {
    final WireRecord? record = records[identifier];
    if (record == null) {
      throw SimulatedRefusal('record $identifier was not found');
    }
    return record;
  }

  String _nextIdentifier() {
    _createdCount += 1;
    return '$_identifierPrefix$_createdCount';
  }
}
