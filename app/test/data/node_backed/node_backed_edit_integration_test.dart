import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/workspace_values.dart'
    as node;
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../support/memory_workspace_choice_store.dart';
import 'support/host_account_harness.dart';

const Duration _pollInterval = Duration(milliseconds: 100);
const Duration _waitStep = Duration(milliseconds: 100);
const Duration _waitLimit = Duration(seconds: 20);
const Timeout _integrationTimeout = Timeout(Duration(minutes: 3));
const String _keptAddress = 'github.com/example/site';
const String _removedAddress = 'github.com/example/docs';

Future<void> _waitUntil(bool Function() isReached) async {
  final DateTime deadline = DateTime.now().add(_waitLimit);
  while (!isReached()) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('the node did not answer in time');
    }
    await Future<void>.delayed(_waitStep);
  }
}

TaskDraft _buildTask(ProjectId projectId, String title) {
  return TaskDraft(
    title: title,
    details: 'Keep it small.',
    projectId: projectId,
    doer: const OneAgentDoer(AgentKind.claudeCode),
    runsOn: const AnyFreeRunner(),
    skills: const <SkillId>[],
    usesAutomaticSkills: false,
    approvalPolicy: ApprovalPolicy.askBeforeRiskyActions,
  );
}

node.Repository _buildRepository(String address) {
  return node.Repository(
    address: address,
    defaultBranch: 'main',
    agentAccess: node.AgentAccess.readOnly,
  );
}

void main() {
  test(
    'test_node_backed_edits_property_changes_reach_the_node',
    () async {
      final HostAccount host = await openHostAccount(
        repositories: <node.Repository>[
          _buildRepository(_keptAddress),
          _buildRepository(_removedAddress),
        ],
      );
      final NodeBackedWorkspaceRepository workspaces =
          NodeBackedWorkspaceRepository(
            channel: host.channel,
            clock: const SystemClock(),
            retryInterval: _pollInterval,
            choiceStore: MemoryWorkspaceChoiceStore(chosenWorkspaceId: null),
          );
      final NodeBackedJobRepository jobs = NodeBackedJobRepository(
        channel: host.channel,
        workspaceRepository: workspaces,
        clock: const SystemClock(),
      );
      final NodeBackedTaskRepository tasks = NodeBackedTaskRepository(
        channel: host.channel,
        workspaceRepository: workspaces,
        livePollInterval: _pollInterval,
        jobRepository: jobs,
      );
      final NodeBackedProjectRepository projects = NodeBackedProjectRepository(
        channel: host.channel,
        workspaceRepository: workspaces,
      );
      addTearDown(tasks.dispose);
      addTearDown(jobs.dispose);
      addTearDown(projects.dispose);
      await workspaces.load();
      await projects.load();

      final Task created = await tasks.createTask(
        _buildTask(host.project.id, 'Fix the footer'),
      );
      final Task renamed = await tasks.updateTask(
        created.id,
        _buildTask(host.project.id, 'Fix the header'),
      );
      expect(renamed.id, created.id);
      expect(tasks.findTask(created.id).title, 'Fix the header');

      final Task job = await jobs.createJob(
        JobDraft(
          task: _buildTask(host.project.id, 'Nightly checks'),
          schedule: DailySchedule(at: ScheduleTime(hour: 2, minute: 0)),
        ),
      );
      final Task moved = await jobs.updateJob(
        job.id,
        JobDraft(
          task: _buildTask(host.project.id, 'Weekly checks'),
          schedule: WeeklySchedule(
            on: Weekday.monday,
            at: ScheduleTime(hour: 9, minute: 30),
          ),
        ),
      );
      expect(moved.schedule, isA<WeeklySchedule>());
      expect(jobs.findJob(job.id).title, 'Weekly checks');

      final Project trimmed = await projects.removeRepository(
        host.project.id,
        _removedAddress,
      );
      expect(
        trimmed.repositories.map((Repository kept) => kept.address),
        <String>[_keptAddress],
      );

      final Run run = await tasks.startTask(created.id);
      tasks.watchRun(run.id);
      await _waitUntil(
        () => tasks.findRun(run.id).link == RunnerLink.unreachable,
      );
      tasks.stopWatchingRun(run.id);
      expect(tasks.findRun(run.id).id, run.id);
    },
    skip: findHostLibrarySkipReason(),
    timeout: _integrationTimeout,
  );
}
