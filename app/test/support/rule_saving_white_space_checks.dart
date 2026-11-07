import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/rules/agents_markdown.dart';

import 'random_inputs.dart';
import 'rule_title_white_space_table.dart';

typedef SaveRule = Future<Rule> Function(RuleDraft draft);
typedef FindRule = Rule Function(RuleId ruleId);

const WorkspaceId _workspaceId = WorkspaceId('workspace');
const ProjectId _projectId = ProjectId('project');

String renderRuleAlone({required String title, required String details}) {
  final Rule rule = Rule(
    id: const RuleId('rule'),
    title: title,
    details: details,
    scope: const Scope.everywhere(),
    enabled: true,
    addedAt: galleryNow,
  );
  return renderAgentsMarkdown(
    rules: <Rule>[rule],
    workspaceId: _workspaceId,
    projectId: _projectId,
  );
}

RuleDraft randomExoticRuleDraft(
  Random random,
  RuleTitleWhiteSpaceTable table,
) {
  return RuleDraft(
    title: table.randomExoticTitle(random),
    details: table.randomExoticTitle(random),
    scope: const Scope.everywhere(),
  );
}

Future<void> checkSavesModelTrimmedTitles({
  required RuleTitleWhiteSpaceTable table,
  required SaveRule saveRule,
  required FindRule findRule,
  required int seed,
}) async {
  final Random random = seededRandom(seed);

  for (int i = 0; i < propertyIterations; i += 1) {
    final RuleDraft draft = randomExoticRuleDraft(random, table);
    final String trimmed = table.trimByModel(draft.title);
    final String reason = draft.title.runes.toString();

    if (trimmed.isEmpty) {
      await expectLater(saveRule(draft), throwsArgumentError, reason: reason);
      continue;
    }
    final Rule saved = await saveRule(draft);
    expect(saved.title, trimmed, reason: reason);
    expect(findRule(saved.id).title, trimmed, reason: reason);
  }
}

Future<void> checkRefusesSharedBlankTitles({
  required RuleTitleWhiteSpaceTable table,
  required SaveRule saveRule,
}) async {
  for (final RuleTitleWhiteSpaceCase sharedCase in table.cases) {
    final RuleDraft draft = RuleDraft(
      title: sharedCase.title,
      details: sharedCase.details,
      scope: const Scope.everywhere(),
    );
    final String reason = sharedCase.title.runes.toString();

    if (sharedCase.isBlank) {
      await expectLater(saveRule(draft), throwsArgumentError, reason: reason);
      continue;
    }
    final Rule saved = await saveRule(draft);
    final String savedMarkdown = renderRuleAlone(
      title: saved.title,
      details: saved.details,
    );
    expect(savedMarkdown, sharedCase.markdown, reason: reason);
  }
}

Future<void> checkSavedRuleRendersLikeDraft({
  required RuleTitleWhiteSpaceTable table,
  required SaveRule saveRule,
  required int seed,
}) async {
  final Random random = seededRandom(seed);

  for (int i = 0; i < propertyIterations; i += 1) {
    final RuleDraft draft = randomExoticRuleDraft(random, table);
    if (table.trimByModel(draft.title).isEmpty) {
      continue;
    }

    final Rule saved = await saveRule(draft);

    final String draftMarkdown = renderRuleAlone(
      title: draft.title,
      details: draft.details,
    );
    final String savedMarkdown = renderRuleAlone(
      title: saved.title,
      details: saved.details,
    );
    expect(savedMarkdown, draftMarkdown, reason: draft.title.runes.toString());
  }
}
