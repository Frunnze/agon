import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_library.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_runners.dart';
import 'package:agent_orchestration/data/gallery/gallery_runs.dart';
import 'package:agent_orchestration/data/gallery/gallery_tasks.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/scope_rules.dart';

import 'support/gallery_records.dart';

Skill _findSkill(SkillId skillId) {
  return gallerySkills.singleWhere((Skill skill) => skill.id == skillId);
}

bool _hasRuns(Task task) {
  return galleryRuns.any((Run run) => run.taskId == task.id);
}

bool _isPlaceOfferedInWorkspace(Task task, WorkspaceId workspaceId) {
  for (final Runner runner in galleryRunners) {
    final Device device = findGalleryDevice(runner.deviceId);
    final bool isMember = device.workspaces.contains(workspaceId);
    if (isMember && runner.offers.contains(task.agentPlace)) {
      return true;
    }
  }
  return false;
}

void main() {
  test('test_gallery_tasks_property_ids_are_unique_across_tasks_and_'
      'jobs', () {
    final List<TaskId> identifiers = <TaskId>[
      for (final Task task in galleryWork) task.id,
    ];

    expect(hasNoRepeats(identifiers), isTrue);
    for (final Task task in galleryWork) {
      expect(task.title.trim(), isNotEmpty);
      expect(task.title, task.title.trim());
    }
  });

  test('test_gallery_tasks_property_only_jobs_repeat', () {
    for (final Task task in galleryTasks) {
      expect(task.schedule, isNull, reason: task.title);
    }
    for (final Task job in galleryJobs) {
      expect(job.schedule, isNotNull, reason: job.title);
    }
  });

  test('test_gallery_tasks_property_doers_are_signed_and_available', () {
    for (final Task task in galleryWork) {
      final Project project = findGalleryProject(task.projectId);
      final TaskDoer doer = task.doer;
      if (doer is! WorkflowDoer) {
        continue;
      }
      final Workflow workflow = findGalleryWorkflow(doer.workflowId);

      expect(workflow.signature, isNotNull, reason: workflow.name);
      expect(
        includesWorkspace(workflow.availability, project.workspaceId),
        isTrue,
        reason: workflow.name,
      );
    }
  });

  test('test_gallery_tasks_property_skills_apply_to_the_project', () {
    for (final Task task in galleryWork) {
      final Project project = findGalleryProject(task.projectId);
      expect(hasNoRepeats(task.skills), isTrue);
      for (final SkillId skillId in task.skills) {
        final bool applies = doesScopeApply(
          scope: _findSkill(skillId).scope,
          workspaceId: project.workspaceId,
          projectId: project.id,
        );

        expect(applies, isTrue, reason: task.title);
      }
    }
  });

  test('test_gallery_tasks_property_place_is_offered_in_the_workspace', () {
    for (final Task task in galleryWork) {
      final Project project = findGalleryProject(task.projectId);

      expect(
        _isPlaceOfferedInWorkspace(task, project.workspaceId),
        isTrue,
        reason: task.title,
      );
    }
  });

  test('test_gallery_tasks_property_created_before_now', () {
    for (final Task task in galleryWork) {
      expect(task.createdAt.isAfter(galleryNow), isFalse, reason: task.title);
    }
  });

  test('test_gallery_tasks_property_only_unstarted_tasks_are_to_do', () {
    for (final Task task in galleryTasks) {
      final bool isToDo = task.status == TaskStatus.toDo;

      expect(_hasRuns(task), !isToDo, reason: task.title);
    }
  });
}
