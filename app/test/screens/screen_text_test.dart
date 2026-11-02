import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_approvals.dart';
import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_runners.dart';
import 'package:agent_orchestration/data/gallery/gallery_runs.dart';
import 'package:agent_orchestration/data/gallery/gallery_tasks.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/approvals/approval_dialog.dart';
import 'package:agent_orchestration/screens/approvals/approval_text.dart';
import 'package:agent_orchestration/screens/chat/chat_context_panel.dart';
import 'package:agent_orchestration/screens/chat/chat_message_views.dart';
import 'package:agent_orchestration/screens/tasks/task_row.dart';
import 'package:agent_orchestration/widgets/fact_list.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

import '../support/random_inputs.dart';

final DeviceNames _deviceNames = DeviceNames(galleryDevices);

String joinSegments(List<TextSegment> segments) {
  return segments.map((TextSegment segment) => segment.text).join();
}

void main() {
  test('test_describe_task_runs_on_property_runner_or_target', () {
    final Random random = seededRandom(6001);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Task task = pickOne(random, galleryTasks);
      final Run? run = random.nextBool() ? pickOne(random, galleryRuns) : null;
      final String text = joinSegments(
        describeTaskRunsOn(
          task: task,
          latestRun: run,
          deviceNames: _deviceNames,
        ),
      );

      expect(text, isNotEmpty);
      if (run == null) {
        expect(text, 'Any runner');
      }
    }
  });

  test('test_describe_task_subtitle_property_starts_with_project', () {
    final Random random = seededRandom(6002);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String project = randomWordPhrase(random);
      final String doer = randomWordPhrase(random);
      final Run? run = random.nextBool() ? pickOne(random, galleryRuns) : null;
      final String subtitle = describeTaskSubtitle(
        projectName: project,
        doerLabel: doer,
        latestRun: run,
      );

      expect(subtitle, startsWith('$project · $doer'));
    }
  });

  test('test_build_task_row_property_keyed_by_task_with_two_meta_cells', () {
    final Random random = seededRandom(6003);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Task task = pickOne(random, galleryTasks);
      final ListRowData row = buildTaskRow(
        task: task,
        latestRun: random.nextBool() ? pickOne(random, galleryRuns) : null,
        projectName: 'acme-app',
        doerLabel: 'Codex',
        deviceNames: _deviceNames,
        now: galleryNow,
        onTap: () {},
      );

      expect(row.key, ValueKey<TaskId>(task.id));
      expect(row.meta.length, 2);
    }
  });

  test('test_describe_approval_title_property_names_the_action', () {
    for (final ApprovalRequest request in galleryApprovals) {
      final String title = describeApprovalTitle(
        request.action,
        galleryWorkflows,
      );
      expect(title, isNotEmpty);
    }
    expect(
      describeApprovalTitle(
        const DeployAction(target: 'production'),
        galleryWorkflows,
      ),
      'Deploy to production',
    );
    expect(
      describeApprovalTitle(
        const DeleteBranchOrFilesAction(
          repository: 'github.com/acme/docs',
          what: 'branch main',
        ),
        galleryWorkflows,
      ),
      'Delete branch main in acme/docs',
    );
  });

  test('test_describe_approval_context_property_mentions_run_label', () {
    final Random random = seededRandom(6005);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String label = 'release #${random.nextInt(500)}';
      final String text = joinSegments(
        describeApprovalContext(
          action: PushCommitsAction(
            repository: 'github.com/acme/app',
            branch: 'release',
            commits: const <String>['a'],
          ),
          runLabel: label,
          change: null,
        ),
      );

      expect(text, '$label · branch release');
    }
    expect(
      joinSegments(
        describeApprovalContext(
          action: galleryApprovals.last.action,
          runLabel: null,
          change: null,
        ),
      ),
      'Not signed yet',
    );
  });

  test('test_describe_waiting_approvals_property_states_the_count', () {
    final Random random = seededRandom(6006);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int count = 1 + random.nextInt(50);
      final String text = describeWaitingApprovals(count);

      expect(text, startsWith('$count waiting.'));
    }
  });

  test('test_describe_waiting_approvals_property_rejects_no_requests', () {
    final Random random = seededRandom(6007);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int count = -random.nextInt(50);

      expect(() => describeWaitingApprovals(count), throwsArgumentError);
    }
  });

  test('test_describe_push_request_property_noun_agrees_with_count', () {
    final Random random = seededRandom(6010);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int commitCount = 1 + random.nextInt(50);
      final String? runLabel = random.nextBool() ? 'run #$i' : null;
      final String expectedEnding = commitCount == 1
          ? 'push 1 commit.'
          : 'push $commitCount commits.';

      final String text = describePushRequest(
        runLabel: runLabel,
        commitCount: commitCount,
      );

      expect(
        text,
        startsWith(
          runLabel == null ? 'An agent wants ' : 'The agent in $runLabel ',
        ),
      );
      expect(text, endsWith(expectedEnding));
    }
  });

  test('test_describe_action_request_property_names_the_asking_agent', () {
    final Random random = seededRandom(6011);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String? runLabel = random.nextBool()
          ? '${randomWordPhrase(random)} #$i'
          : null;

      final String text = describeActionRequest(runLabel: runLabel);

      expect(text, endsWith(' asks before it does this.'));
      if (runLabel == null) {
        expect(text, 'An agent asks before it does this.');
      } else {
        expect(text, 'The agent in $runLabel asks before it does this.');
      }
    }
  });

  test('test_describe_push_destination_property_names_hosts_and_folders', () {
    final Random random = seededRandom(6007);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String path = randomWordPhrase(random).replaceAll(' ', '-');
      final String folderName = pickOne(random, <String>['billing', 'a b']);
      final String folderAddress = 'local:3f2a9c:/Users/someone/$folderName';
      expect(describePushDestination('github.com/$path'), 'GitHub');
      expect(
        describePushDestination('git.example.org/$path'),
        'git.example.org',
      );
      expect(describePushDestination(folderAddress), folderName);
    }
  });

  test('test_choose_tool_step_icon_property_errors_always_alert', () {
    final Random random = seededRandom(6008);

    for (int i = 0; i < propertyIterations; i += 1) {
      final bool isError = random.nextBool();
      final String text = pickOne(random, <String>[
        'Ran xcodebuild',
        'Edited a file',
        randomText(random),
      ]);
      final AppIconKind icon = chooseToolStepIcon(
        ChatMessage(
          at: galleryNow,
          author: ChatAuthor.tool,
          text: text,
          isError: isError,
          waitingToSend: false,
        ),
      );

      if (isError) {
        expect(icon, AppIconKind.alert);
      } else {
        expect(icon == AppIconKind.alert, isFalse);
      }
    }
  });

  test('test_build_runner_facts_property_sandbox_and_hosts', () {
    for (final Runner runner in galleryRunners) {
      final List<Fact> facts = buildRunnerFacts(runner);
      expect(facts.map((Fact fact) => fact.term), <String>[
        'Sandbox',
        'Can reach',
      ]);
      expect(
        joinSegments(facts.first.description),
        describeSandbox(runner.sandbox),
      );
    }
    for (final SandboxKind sandbox in SandboxKind.values) {
      expect(describeSandbox(sandbox), endsWith('.'));
    }
  });
}
