import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';

import '../../support/app_harness.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../../support/scripted_item_draft_repository.dart';
import 'draft_record_fields.dart';
import 'new_item_harness.dart';
import 'random_drafts.dart';

List<Object?> _describeDraftedItem(DraftedItem item) {
  switch (item) {
    case DraftedWork():
      return describeDraftedWorkFields(item);
    case DraftedSkill(:final SkillDraft skill):
      return describeSkillFields(
        name: skill.name,
        summary: skill.summary,
        instructions: skill.instructions,
        scope: skill.scope,
        usage: skill.usage,
        improvement: skill.improvement,
      );
    case DraftedRule(:final RuleDraft rule):
      return describeRuleFields(
        title: rule.title,
        details: rule.details,
        scope: rule.scope,
      );
  }
}

Task _findNewestWork(AppDependencies dependencies, DraftedWork work) {
  if (work.schedule == null) {
    return dependencies.taskRepository.listTasks().first;
  }
  return dependencies.jobRepository.listJobs().first;
}

List<Object?> _describeSavedItem(
  AppDependencies dependencies,
  DraftedItem item,
) {
  switch (item) {
    case DraftedWork():
      return describeSavedWorkFields(_findNewestWork(dependencies, item));
    case DraftedSkill():
      final Skill skill = dependencies.skillRepository.listSkills().last;
      return describeSkillFields(
        name: skill.name,
        summary: skill.summary,
        instructions: skill.instructions,
        scope: skill.scope,
        usage: skill.usage,
        improvement: skill.improvement,
      );
    case DraftedRule():
      final Rule rule = dependencies.ruleRepository.listRules().last;
      return describeRuleFields(
        title: rule.title,
        details: rule.details,
        scope: rule.scope,
      );
  }
}

void main() {
  testWidgets(
    'test_new_item_screen_property_unedited_draft_is_saved_exactly',
    (WidgetTester tester) async {
      final Random random = seededRandom(9901);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final DraftKind kind = DraftKind.values[i % DraftKind.values.length];
        final DraftedItem item = randomDraftedItem(random, kind, i);
        final ScriptedItemDraftRepository drafts =
            ScriptedItemDraftRepository();
        final AppDependencies dependencies = buildNewItemDependencies(drafts);
        await openNewItem(
          tester,
          route: newItemRoutes[kind]!,
          dependencies: dependencies,
        );
        await startNewItemDraft(tester, describeNewItem(kind).draftLabel);
        await finishNewItemDraft(
          tester,
          drafts,
          ItemDraft(item: item, problems: const <String>[]),
        );

        await tapVisible(tester, findAppButton(approveLabel));
        await pumpFrames(tester);

        expect(
          _describeSavedItem(dependencies, item),
          _describeDraftedItem(item),
          reason: '$kind round $i',
        );
      }
    },
  );
}
