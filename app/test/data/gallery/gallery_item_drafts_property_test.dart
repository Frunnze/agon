import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_item_drafts.dart';
import 'package:agent_orchestration/data/gallery/gallery_library.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/rules/naming.dart';
import 'package:agent_orchestration/data/rules/rule_titles.dart';
import 'package:agent_orchestration/data/rules/scope_rules.dart';
import 'package:agent_orchestration/data/rules/skill_names.dart';

import 'support/gallery_records.dart';

const WorkspaceId _draftingWorkspace = GalleryWorkspaceIds.acme;

Skill _findSkill(SkillId skillId) {
  return gallerySkills.singleWhere((Skill skill) => skill.id == skillId);
}

void _expectWorkPassesTheNodeChecks(DraftedWork work, DraftKind kind) {
  final ProjectId? projectId = work.projectId;
  expect(work.title.trim(), isNotEmpty);
  expect(projectId, isNotNull, reason: work.title);

  final Project project = findGalleryProject(projectId!);
  expect(project.workspaceId, _draftingWorkspace);
  expect(work.schedule != null, kind == DraftKind.job, reason: work.title);
  for (final SkillId skillId in work.skills) {
    final Skill skill = _findSkill(skillId);
    final bool applies = doesScopeApply(
      scope: skill.scope,
      workspaceId: project.workspaceId,
      projectId: project.id,
    );
    expect(applies, isTrue, reason: skill.name);
  }
  if (work.doer case WorkflowDoer(:final WorkflowId workflowId)) {
    expect(findGalleryWorkflow(workflowId).signature, isNotNull);
  }
}

void _expectScopeInDraftingWorkspace(Scope scope) {
  if (scope.workspaces case OnlyWorkspaces(
    :final List<WorkspaceId> workspaces,
  )) {
    expect(workspaces, <WorkspaceId>[_draftingWorkspace]);
  }
  if (scope.projects case OnlyProjects(:final List<ProjectId> projects)) {
    expect(projects, isNotEmpty);
    for (final ProjectId projectId in projects) {
      final Project project = findGalleryProject(projectId);
      expect(project.workspaceId, _draftingWorkspace);
    }
  }
}

void _expectSkillPassesTheNodeChecks(SkillDraft skill) {
  expect(describeNameProblem(skill.name), isNull, reason: skill.name);
  requireValidSkillName(skill.name);
  requireFreeSkillName(name: skill.name, otherSkills: gallerySkills);
  expect(skill.summary.trim(), isNotEmpty);
  expect(skill.instructions.trim(), isNotEmpty);
  _expectScopeInDraftingWorkspace(skill.scope);
}

void main() {
  test('test_build_gallery_item_drafts_property_one_draft_per_kind', () {
    final Map<DraftKind, ItemDraft> drafts = buildGalleryItemDrafts();

    expect(drafts.keys.toSet(), DraftKind.values.toSet());
    for (final MapEntry<DraftKind, ItemDraft> entry in drafts.entries) {
      final DraftedItem item = entry.value.item;
      final bool hasMatchingType = switch (entry.key) {
        DraftKind.task || DraftKind.job => item is DraftedWork,
        DraftKind.skill => item is DraftedSkill,
        DraftKind.rule => item is DraftedRule,
      };
      expect(hasMatchingType, isTrue, reason: entry.key.name);
    }
  });

  test('test_build_gallery_item_drafts_property_approvable_drafts_pass_'
      'the_node_checks', () {
    final Map<DraftKind, ItemDraft> drafts = buildGalleryItemDrafts();

    for (final MapEntry<DraftKind, ItemDraft> entry in drafts.entries) {
      final ItemDraft draft = entry.value;
      expect(draft.problems, isEmpty, reason: entry.key.name);

      switch (draft.item) {
        case final DraftedWork work:
          _expectWorkPassesTheNodeChecks(work, entry.key);
        case DraftedSkill(:final SkillDraft skill):
          _expectSkillPassesTheNodeChecks(skill);
        case DraftedRule(:final RuleDraft rule):
          requireRuleTitle(rule.title);
          expect(rule.details.trim(), isNotEmpty);
          _expectScopeInDraftingWorkspace(rule.scope);
      }
    }
  });

  test('test_build_gallery_item_drafts_property_each_call_builds_a_fresh_'
      'map', () {
    final Map<DraftKind, ItemDraft> first = buildGalleryItemDrafts();
    final Map<DraftKind, ItemDraft> second = buildGalleryItemDrafts();

    expect(identical(first, second), isFalse);
    first.remove(DraftKind.rule);

    expect(second.keys.toSet(), DraftKind.values.toSet());
    expect(buildGalleryItemDrafts().keys.toSet(), DraftKind.values.toSet());
  });

  test('test_build_gallery_item_drafts_property_work_drafts_turn_into_'
      'task_drafts', () {
    final Map<DraftKind, ItemDraft> drafts = buildGalleryItemDrafts();

    for (final ItemDraft draft in drafts.values) {
      final DraftedItem item = draft.item;
      if (item is! DraftedWork) {
        continue;
      }
      final TaskDraft taskDraft = item.toTaskDraft();

      expect(taskDraft.title, item.title);
      expect(taskDraft.projectId, item.projectId);
      expect(taskDraft.skills, item.skills);
    }
  });
}
