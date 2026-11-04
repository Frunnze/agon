import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/gallery/gallery_approvals.dart';
import 'package:agent_orchestration/data/gallery/gallery_chat.dart';
import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_library.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_runners.dart';
import 'package:agent_orchestration/data/gallery/gallery_runs.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/conversation.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';

import '../../support/random_inputs.dart';
import '../../support/sample_records.dart';

void main() {
  test('test_to_draft_property_round_trips_through_from_draft', () {
    final Random random = seededRandom(1101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskDraft draft = randomTaskDraft(random);
      final Task task = Task.fromDraft(
        id: const TaskId('task'),
        draft: draft,
        schedule: null,
        status: pickOne(random, TaskStatus.values),
        createdAt: galleryNow,
      );
      final TaskDraft roundTripped = task.toDraft();

      expect(roundTripped.title, draft.title);
      expect(roundTripped.details, draft.details);
      expect(roundTripped.projectId, draft.projectId);
      expect(roundTripped.doer, draft.doer);
      expect(roundTripped.runsOn, draft.runsOn);
      expect(roundTripped.skills, draft.skills);
      expect(roundTripped.approvalPolicy, draft.approvalPolicy);
      expect(() => task.skills.add(sampleSkillIds.first), throwsA(anything));
    }
  });

  test('test_with_status_property_changes_only_status', () {
    final Random random = seededRandom(1102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Task task = Task.fromDraft(
        id: const TaskId('task'),
        draft: randomTaskDraft(random),
        schedule: randomJobSchedule(random),
        status: TaskStatus.toDo,
        createdAt: galleryNow,
      );
      final TaskStatus status = pickOne(random, TaskStatus.values);
      final Task changed = task.withStatus(status);

      expect(changed.status, status);
      expect(changed.id, task.id);
      expect(changed.schedule, same(task.schedule));
      expect(changed.title, task.title);
    }
  });

  test('test_equality_property_doers_and_targets_compare_by_value', () {
    final Random random = seededRandom(1103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskDoer doer = randomTaskDoer(random);
      final TaskDoer other = randomTaskDoer(random);
      final RunnerTarget target = randomRunnerTarget(random);
      final RunnerTarget otherTarget = randomRunnerTarget(random);

      expect(doer == other, doer.hashCode == other.hashCode);
      expect(target == otherTarget, target.hashCode == otherTarget.hashCode);
      expect(doer == doer, isTrue);
    }
  });

  test('test_from_iso_number_property_round_trips_weekdays', () {
    final Random random = seededRandom(1104);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Weekday weekday = pickOne(random, Weekday.values);
      expect(Weekday.fromIsoNumber(weekday.isoNumber), weekday);
      final int outside = random.nextBool() ? -random.nextInt(9) : 8;
      expect(() => Weekday.fromIsoNumber(outside), throwsRangeError);
    }
  });

  test('test_schedule_time_property_rejects_impossible_clock_values', () {
    final Random random = seededRandom(1105);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int hour = random.nextInt(40) - 8;
      final int minute = random.nextInt(80) - 10;
      final bool isValid =
          hour >= 0 && hour < 24 && minute >= 0 && minute < 60;

      if (isValid) {
        expect(ScheduleTime(hour: hour, minute: minute).hour, hour);
        expect(HourlySchedule(minute: minute).minute, minute);
      } else {
        expect(
          () => ScheduleTime(hour: hour, minute: minute),
          throwsRangeError,
        );
      }
    }
  });

  test('test_device_copies_property_keep_identity', () {
    final Random random = seededRandom(1106);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Device device = pickOne(random, galleryDevices);
      final Device revoked = device.asRevoked();
      final Device moved = device.withWorkspaces(const <WorkspaceId>[]);

      expect(revoked.revoked, isTrue);
      expect(revoked.id, device.id);
      expect(moved.workspaces, isEmpty);
      expect(moved.name, device.name);
    }
  });

  test('test_runner_and_rule_copies_property_flip_only_one_field', () {
    final Random random = seededRandom(1107);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Runner runner = pickOne(random, galleryRunners);
      final Rule rule = pickOne(random, galleryRules);

      expect(runner.asPaused().acceptingNewRuns, isFalse);
      expect(runner.asAcceptingNewRuns().acceptingNewRuns, isTrue);
      expect(runner.asPaused().labels, runner.labels);
      expect(rule.asEnabled().enabled, isTrue);
      expect(rule.asDisabled().enabled, isFalse);
      expect(rule.asDisabled().title, rule.title);
    }
  });

  test('test_run_copies_property_keep_identity_and_branch', () {
    final Random random = seededRandom(1108);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = pickOne(random, galleryRuns);
      final StepStatus status = pickOne(random, StepStatus.values);
      final RunStep step = run.steps.first.withStatus(status);
      final Run changed = run.withProgress(
        nextStatus: pickOne(random, RunStatus.values),
        nextSteps: <RunStep>[step],
        nextFinishedAt: galleryNow,
      );

      expect(step.status, status);
      expect(step.name, run.steps.first.name);
      expect(changed.id, run.id);
      expect(changed.worktreeBranch, run.worktreeBranch);
      expect(changed.steps.single.status, status);
    }
  });

  test('test_conversation_and_approval_copies_property_keep_identity', () {
    final Random random = seededRandom(1109);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Conversation conversation = galleryConversationReconnecting;
      final int keep = random.nextInt(conversation.messages.length);
      final Conversation trimmed = conversation.withMessages(
        conversation.messages.take(keep).toList(),
      );
      final ApprovalRequest request = pickOne(random, galleryApprovals);
      final ApprovalRequest decided = request.withDecision(
        SignedDecision(
          decision: pickOne(random, ApprovalDecision.values),
          decidedBy: request.requestedBy,
          decidedAt: galleryNow,
          signature: const <int>[],
        ),
      );

      expect(trimmed.messages.length, keep);
      expect(trimmed.link, conversation.link);
      expect(decided.isPending, isFalse);
      expect(request.isPending, isTrue);
      expect(decided.id, request.id);
    }
  });

  test('test_find_agent_property_finds_every_agent', () {
    final Random random = seededRandom(1110);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = pickOne(random, galleryWorkflows);
      final WorkflowAgent agent = pickOne(random, workflow.agents);
      expect(workflow.findAgent(agent.id).name, agent.name);
      expect(
        () => workflow.findAgent(WorkflowAgentId(randomText(random))),
        throwsStateError,
      );
    }
  });

  test('test_with_repositories_property_replaces_the_list', () {
    final Random random = seededRandom(1111);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Project project = Project(
        id: const ProjectId('project'),
        workspaceId: const WorkspaceId('workspace'),
        name: randomWordPhrase(random),
        repositories: const <Repository>[],
        approvalPolicy: randomInheritableApprovalPolicy(random),
      );
      final Repository repository = Repository(
        address: 'github.com/acme/${random.nextInt(99)}',
        defaultBranch: 'main',
        agentAccess: pickOne(random, AgentAccess.values),
      );
      final Project changed = project.withRepositories(<Repository>[
        repository,
      ]);

      expect(changed.repositories.single.address, repository.address);
      expect(changed.name, project.name);
      expect(changed.approvalPolicy, project.approvalPolicy);
    }
  });

  test('test_now_property_fixed_clock_is_stable_and_system_moves', () {
    final Random random = seededRandom(1112);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime moment = randomUtcMoment(random);
      final FixedClock clock = FixedClock(moment);
      expect(clock.now(), moment);
      expect(clock.now(), clock.now());
    }
    final DateTime before = DateTime.now();
    expect(const SystemClock().now().isBefore(before), isFalse);
    expect(galleryRunChat, isNotEmpty);
  });
}
