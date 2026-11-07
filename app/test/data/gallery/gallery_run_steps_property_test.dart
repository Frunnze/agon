import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_files.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_runners.dart';
import 'package:agent_orchestration/data/gallery/gallery_runs.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/device_roles.dart';
import 'package:agent_orchestration/data/rules/task_branch.dart';
import 'package:agent_orchestration/data/rules/workflow_graph.dart';

import 'support/gallery_records.dart';
import 'support/node_run_rules.dart';

const int _shownSessionEdgeLength = 4;
const String _sessionEllipsis = '…';

Project _findRunProject(Run run) {
  return findGalleryProject(findGalleryWork(run.taskId).projectId);
}

void _expectRunnerFitsTarget(DeviceId runnerId, RunnerTarget target) {
  switch (target) {
    case AnyFreeRunner():
      return;
    case SpecificRunner(:final DeviceId deviceId):
      expect(runnerId, deviceId);
    case RunnerWithLabels(:final List<String> labels):
      final Runner runner = galleryRunners.singleWhere(
        (Runner runner) => runner.deviceId == runnerId,
      );
      expect(runner.labels, containsAll(labels));
  }
}

RunnerTarget _findStepTarget(Task task, RunStep step) {
  final TaskDoer doer = task.doer;
  if (doer is WorkflowDoer) {
    return findGalleryWorkflow(doer.workflowId)
        .findAgent(step.agentId!)
        .runsOn;
  }
  return task.runsOn;
}

void main() {
  test('test_gallery_runs_property_steps_follow_the_doer', () {
    for (final Run run in galleryRuns) {
      final TaskDoer doer = findGalleryWork(run.taskId).doer;
      switch (doer) {
        case WorkflowDoer(:final WorkflowId workflowId):
          final List<WorkflowAgent> ordered = orderAgents(
            findGalleryWorkflow(workflowId),
          );
          expect(
            <String>[for (final RunStep step in run.steps) step.name],
            <String>[for (final WorkflowAgent agent in ordered) agent.name],
          );
          expect(
            <WorkflowAgentId?>[
              for (final RunStep step in run.steps) step.agentId,
            ],
            <WorkflowAgentId>[
              for (final WorkflowAgent agent in ordered) agent.id,
            ],
          );
        case OneAgentDoer(:final AgentKind agent):
          expect(run.steps.single.name, nodeOneAgentStepNames[agent]);
          expect(run.steps.single.agentId, isNull);
      }
    }
  });

  test('test_gallery_runs_property_step_runners_fit_their_targets', () {
    for (final Run run in galleryRuns) {
      final Task task = findGalleryWork(run.taskId);
      final Project project = _findRunProject(run);
      for (final RunStep step in run.steps) {
        final DeviceId? runnerId = step.runner;
        if (step.startedAt != null) {
          expect(runnerId, isNotNull, reason: step.name);
        }
        if (runnerId == null) {
          continue;
        }
        final Device runner = findGalleryDevice(runnerId);

        expect(roleRunsTasks(runner.role), isTrue, reason: step.name);
        expect(runner.workspaces, contains(project.workspaceId));
        _expectRunnerFitsTarget(runnerId, _findStepTarget(task, step));
      }
    }
  });

  test('test_gallery_runs_property_branches_belong_to_the_task', () {
    for (final Run run in galleryRuns) {
      final Task task = findGalleryWork(run.taskId);
      final String? branch = run.worktreeBranch;

      expect(branch, isNotNull, reason: run.id.value);
      expect(branch, startsWith(describeTaskBranch(task.title)));
    }
  });

  test('test_gallery_runs_property_branches_are_listed_on_the_runner', () {
    for (final Run run in galleryRuns) {
      final Project project = _findRunProject(run);
      for (final Repository repository in project.repositories) {
        final RepositoryFileSource? source =
            galleryFileSources[repository.address];
        if (source is! FilesFromRunner) {
          continue;
        }

        expect(source.taskBranches, contains(run.worktreeBranch));
      }
    }
  });

  test('test_gallery_runs_property_log_lines_name_steps_in_time_order', () {
    for (final Run run in galleryRuns) {
      final Set<String> stepNames = <String>{
        for (final RunStep step in run.steps) step.name,
      };
      for (int index = 0; index < run.log.length; index += 1) {
        final LogLine line = run.log[index];

        expect(stepNames, contains(line.stepName), reason: line.text);
        expect(line.at.isAfter(galleryNow), isFalse, reason: line.text);
        if (index > 0) {
          expect(line.at.isBefore(run.log[index - 1].at), isFalse);
        }
      }
    }
  });

  test('test_gallery_runs_property_agent_session_is_named_in_the_log', () {
    for (final Run run in galleryRuns) {
      final String? session = run.agentSession;
      if (session == null) {
        continue;
      }
      final String start = session.substring(0, _shownSessionEdgeLength);
      final String end = session.substring(
        session.length - _shownSessionEdgeLength,
      );

      final String shownSession = '$start$_sessionEllipsis$end';
      final bool isNamed = run.log.any(
        (LogLine line) => line.text.contains(shownSession),
      );

      expect(isNamed, isTrue, reason: run.id.value);
    }
  });
}
