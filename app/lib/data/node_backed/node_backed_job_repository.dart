import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/schedule_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/task_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/task_views.dart' as node;
import 'package:agent_orchestration/bridge/commands/deletion_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/commands/task_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/repository/job_repository.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/data/rules/schedule_time_zone.dart';

const String _jobKind = 'job';

final class NodeBackedJobRepository extends ChangeNotifier
    implements JobRepository, NodeSynchronized {
  NodeBackedJobRepository({
    required NodeCommandChannel channel,
    required WorkspaceRepository workspaceRepository,
    required Clock clock,
  }) : _channel = channel,
       _workspaceRepository = workspaceRepository,
       _clock = clock {
    _workspaceRepository.addListener(_loadAfterWorkspaceChange);
  }

  final NodeCommandChannel _channel;
  final WorkspaceRepository _workspaceRepository;
  final Clock _clock;
  final FetchSequence _fetches = FetchSequence();
  List<Task> _jobs = const <Task>[];

  @override
  List<Task> listJobs() => _jobs;

  @override
  Task findJob(TaskId jobId) {
    return findRecord(
      _jobs,
      matches: (Task job) => job.id == jobId,
      kind: _jobKind,
      identifier: jobId.value,
    );
  }

  @override
  Future<void> load() async {
    final int fetch = _fetches.startFetch();
    final List<Task> jobs = await _fetchJobs();
    if (!_fetches.acceptIfNewest(fetch)) {
      return;
    }

    _jobs = jobs;
    notifyListeners();
  }

  @override
  Future<void> applyChange(node.ChangeTopic topic) async {
    switch (topic) {
      case node.AreaChanged(area: node.ChangeArea.tasks):
      case node.RunChanged():
        await load();
      case node.AreaChanged():
        return;
    }
  }

  @override
  Future<Task> createJob(JobDraft draft) async {
    final node.CreateJobCommand command = node.CreateJobCommand(
      task: mapTaskDraftToNode(
        draft: draft.task,
        workspaceId: _workspaceRepository.currentWorkspace().id,
      ),
      schedule: _mapScheduleToNode(draft.schedule),
    );
    final node.Task created = await executeNodeCommand(_channel, command);

    await load();
    return _mapJobFromNode(created);
  }

  @override
  Future<Task> updateJob(TaskId jobId, JobDraft draft) async {
    final node.UpdateJobCommand command = node.UpdateJobCommand(
      taskId: jobId,
      task: mapTaskDraftToNode(
        draft: draft.task,
        workspaceId: _workspaceRepository.currentWorkspace().id,
      ),
      schedule: _mapScheduleToNode(draft.schedule),
    );
    final node.Task updated = await executeNodeCommand(_channel, command);

    await load();
    return _mapJobFromNode(updated);
  }

  @override
  Future<void> deleteJob(TaskId jobId) async {
    findJob(jobId);
    await executeNodeCommand(_channel, node.DeleteTaskCommand(taskId: jobId));
    await load();
  }

  @override
  void dispose() {
    _workspaceRepository.removeListener(_loadAfterWorkspaceChange);
    super.dispose();
  }

  void _loadAfterWorkspaceChange() {
    startBackgroundNodeWork(load);
  }

  Future<List<Task>> _fetchJobs() async {
    final WorkspaceId? workspaceId = findCurrentWorkspaceId(
      _workspaceRepository,
    );
    if (workspaceId == null) {
      return const <Task>[];
    }

    final List<node.JobView> views = await executeNodeCommand(
      _channel,
      node.ListJobsCommand(workspaceId: workspaceId),
    );
    final List<Task> jobs = <Task>[
      for (final node.JobView view in views) _mapJobFromNode(view.task),
    ];
    return List<Task>.unmodifiable(jobs);
  }

  node.Schedule _mapScheduleToNode(Schedule localSchedule) {
    final Schedule utcSchedule = convertScheduleToUtc(
      localSchedule,
      utcOffset: _clock.now().timeZoneOffset,
    );
    return mapScheduleToNode(utcSchedule);
  }

  Task _mapJobFromNode(node.Task wireJob) {
    final Task utcJob = mapTaskFromNode(wireJob);
    final Schedule? utcSchedule = utcJob.schedule;
    if (utcSchedule == null) {
      throw StateError(
        'the node sent job ${utcJob.id.value} without a schedule',
      );
    }

    final Schedule localSchedule = convertScheduleFromUtc(
      utcSchedule,
      utcOffset: _clock.now().timeZoneOffset,
    );
    return Task.fromDraft(
      id: utcJob.id,
      draft: utcJob.toDraft(),
      schedule: localSchedule,
      status: utcJob.status,
      createdAt: utcJob.createdAt,
    );
  }
}
