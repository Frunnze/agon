import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/screens/new_items/change_request_composer.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';
import 'package:agent_orchestration/widgets/forms/form_field_block.dart';

import '../../support/app_harness.dart';
import '../../support/form_finders.dart';
import '../../support/scripted_item_draft_repository.dart';
import 'new_item_harness.dart';

const String _taskTitleLabel = 'What should be done?';
const String _handTaskTitle = 'Prune stale branches';
const String _agentTaskTitle = 'Prune the stale branches weekly';
const String _changeNote = 'Ask before pushing';

const Map<DraftKind, String> _editedFieldLabels = <DraftKind, String>{
  DraftKind.task: _taskTitleLabel,
  DraftKind.job: _taskTitleLabel,
  DraftKind.project: 'Name',
  DraftKind.skill: 'Name',
  DraftKind.rule: 'Rule',
};

const Map<DraftKind, String> _handValues = <DraftKind, String>{
  DraftKind.task: _handTaskTitle,
  DraftKind.job: 'Update the lockfiles',
  DraftKind.project: 'billing-by-hand',
  DraftKind.skill: 'release-notes-by-hand',
  DraftKind.rule: 'Write small commits',
};

List<String> _listSavedNames(AppDependencies dependencies, DraftKind kind) {
  switch (kind) {
    case DraftKind.task || DraftKind.job:
      final List<Task> work = <Task>[
        ...dependencies.taskRepository.listTasks(),
        ...dependencies.jobRepository.listJobs(),
      ];
      return <String>[for (final Task task in work) task.title];
    case DraftKind.project:
      final List<Project> projects = dependencies.projectRepository
          .listProjects(
            dependencies.workspaceRepository.currentWorkspace().id,
          );
      return <String>[for (final Project project in projects) project.name];
    case DraftKind.skill:
      return <String>[
        for (final Skill skill in dependencies.skillRepository.listSkills())
          skill.name,
      ];
    case DraftKind.rule:
      return <String>[
        for (final Rule rule in dependencies.ruleRepository.listRules())
          rule.title,
      ];
  }
}

Future<void> _showGalleryDraft(
  WidgetTester tester, {
  required DraftKind kind,
  required ScriptedItemDraftRepository drafts,
  required AppDependencies dependencies,
}) async {
  await openNewItem(
    tester,
    route: newItemRoutes[kind]!,
    dependencies: dependencies,
  );
  await startNewItemDraft(tester, describeNewItem(kind).draftLabel);
  await finishNewItemDraft(tester, drafts, findGalleryItemDraft(kind));
}

String _readFieldText(WidgetTester tester, String label) {
  final TextField field = tester.widget(findFieldInput(label));
  return field.controller!.text;
}

Future<void> _askAgentForChange(WidgetTester tester) async {
  final Finder noteField = find.descendant(
    of: find.byType(ChangeRequestComposer),
    matching: find.byType(TextField),
  );
  await tester.ensureVisible(noteField);
  await tester.enterText(noteField, _changeNote);
  await tapVisible(tester, findAppButton(sendChangeLabel));
  await pumpFrames(tester);
}

void main() {
  for (final DraftKind kind in DraftKind.values) {
    testWidgets('a hand edit of the ${kind.name} draft is what is saved', (
      WidgetTester tester,
    ) async {
      final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
      final AppDependencies dependencies = buildNewItemDependencies(drafts);
      await _showGalleryDraft(
        tester,
        kind: kind,
        drafts: drafts,
        dependencies: dependencies,
      );

      await enterFieldText(
        tester,
        label: _editedFieldLabels[kind]!,
        text: _handValues[kind]!,
      );
      await tapVisible(tester, findAppButton(approveLabel));
      await pumpFrames(tester);

      expect(_listSavedNames(dependencies, kind), contains(_handValues[kind]));
    });

    testWidgets('the ask row sits under the ${kind.name} fields, as wide', (
      WidgetTester tester,
    ) async {
      final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
      await _showGalleryDraft(
        tester,
        kind: kind,
        drafts: drafts,
        dependencies: buildNewItemDependencies(drafts),
      );

      final Rect askRow = tester.getRect(find.byType(ChangeRequestComposer));
      final Rect firstField = tester.getRect(
        find.byType(FormFieldBlock).first,
      );
      final Rect lastField = tester.getRect(find.byType(FormFieldBlock).last);
      expect(askRow.top, greaterThan(lastField.bottom));
      expect(askRow.left, firstField.left);
      expect(askRow.width, firstField.width);
    });
  }

  testWidgets('an agent change after a hand edit starts from the edit', (
    WidgetTester tester,
  ) async {
    final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
    await _showGalleryDraft(
      tester,
      kind: DraftKind.task,
      drafts: drafts,
      dependencies: buildNewItemDependencies(drafts),
    );
    final DraftedWork agentDraft =
        findGalleryItemDraft(DraftKind.task).item as DraftedWork;

    await enterFieldText(tester, label: _taskTitleLabel, text: _handTaskTitle);
    await _askAgentForChange(tester);

    final ItemDraftChange change = drafts.latestRequest.change!;
    final DraftedWork sentDraft = change.draft as DraftedWork;
    expect(change.note, _changeNote);
    expect(sentDraft.title, _handTaskTitle);
    expect(sentDraft.details, agentDraft.details);

    final DraftedWork answer = DraftedWork(
      title: _agentTaskTitle,
      details: sentDraft.details,
      projectId: sentDraft.projectId,
      doer: sentDraft.doer,
      runsOn: sentDraft.runsOn,
      agentPlace: sentDraft.agentPlace,
      skills: sentDraft.skills,
      usesAutomaticSkills: sentDraft.usesAutomaticSkills,
      approvalPolicy: sentDraft.approvalPolicy,
      schedule: sentDraft.schedule,
    );
    await finishNewItemDraft(
      tester,
      drafts,
      ItemDraft(item: answer, problems: const <String>[]),
    );

    expect(_readFieldText(tester, _taskTitleLabel), _agentTaskTitle);
  });

  testWidgets('back to the draft keeps the hand edit', (
    WidgetTester tester,
  ) async {
    final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
    await _showGalleryDraft(
      tester,
      kind: DraftKind.task,
      drafts: drafts,
      dependencies: buildNewItemDependencies(drafts),
    );

    await enterFieldText(tester, label: _taskTitleLabel, text: _handTaskTitle);
    await _askAgentForChange(tester);
    drafts.failLatestDraft(StateError('the agent broke'));
    await pumpFrames(tester);
    await tester.tap(find.text(backToDraftLabel));
    await pumpFrames(tester);

    expect(_readFieldText(tester, _taskTitleLabel), _handTaskTitle);
  });
}
