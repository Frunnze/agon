import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/rules/agents_markdown.dart';
import 'package:agent_orchestration/data/rules/scope_rules.dart';

import '../../support/random_inputs.dart';
import '../../support/sample_records.dart';
import '../../support/sample_scopes.dart';

const List<String> _whitespaceCharacters = <String>[
  ' ',
  '\t',
  '\n',
  '\r',
  '\u000B',
  '\u0085',
  ' ',
  ' ',
  ' ',
  '　',
];
const int _mostWhitespace = 6;
const int _mostRules = 6;
const String _itemPrefix = '- ';
const String _emptyItemLine = '- .';

String _randomBlankTitle(Random random) {
  final int length = random.nextInt(_mostWhitespace + 1);
  final StringBuffer title = StringBuffer();
  for (int i = 0; i < length; i += 1) {
    title.write(pickOne(random, _whitespaceCharacters));
  }
  return title.toString();
}

String _randomBlankOrWrittenTitle(Random random) {
  if (random.nextBool()) {
    return _randomBlankTitle(random);
  }
  return 'Rule ${randomWordPhrase(random)}';
}

Rule _randomRule(Random random, int index) {
  return Rule(
    id: RuleId('rule-$index'),
    title: _randomBlankOrWrittenTitle(random),
    details: randomText(random),
    scope: randomScope(random),
    enabled: random.nextBool(),
    addedAt: galleryNow,
  );
}

List<Rule> _randomRules(Random random) {
  final int ruleCount = random.nextInt(_mostRules);
  final List<Rule> rules = <Rule>[];
  for (int index = 0; index < ruleCount; index += 1) {
    rules.add(_randomRule(random, index));
  }
  return rules;
}

bool _hasBlankTitle(Rule rule) {
  return rule.title.trim().isEmpty;
}

void main() {
  test('test_render_agents_markdown_property_skips_blank_title_rules', () {
    final Random random = seededRandom(7311);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Rule> rules = _randomRules(random);
      final List<Rule> titledRules = <Rule>[];
      for (final Rule rule in rules) {
        if (!_hasBlankTitle(rule)) {
          titledRules.add(rule);
        }
      }
      final WorkspaceId workspaceId = pickOne(random, sampleWorkspaceIds);
      final ProjectId projectId = pickOne(random, sampleProjectIds);

      final String withBlankRules = renderAgentsMarkdown(
        rules: rules,
        workspaceId: workspaceId,
        projectId: projectId,
      );
      final String withoutBlankRules = renderAgentsMarkdown(
        rules: titledRules,
        workspaceId: workspaceId,
        projectId: projectId,
      );

      expect(withBlankRules, withoutBlankRules);
    }
  });

  test(
    'test_render_agents_markdown_property_only_blank_titles_give_no_file',
    () {
      final Random random = seededRandom(7312);

      for (int i = 0; i < propertyIterations; i += 1) {
        final List<Rule> rules = <Rule>[];
        for (int index = 0; index <= random.nextInt(_mostRules); index += 1) {
          rules.add(
            Rule(
              id: RuleId('rule-$index'),
              title: _randomBlankTitle(random),
              details: randomText(random),
              scope: const Scope.everywhere(),
              enabled: true,
              addedAt: galleryNow,
            ),
          );
        }

        final String markdown = renderAgentsMarkdown(
          rules: rules,
          workspaceId: pickOne(random, sampleWorkspaceIds),
          projectId: pickOne(random, sampleProjectIds),
        );

        expect(markdown, isEmpty);
      }
    },
  );

  test('test_render_agents_markdown_property_every_item_names_its_rule', () {
    final Random random = seededRandom(7313);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Rule> rules = _randomRules(random);
      final WorkspaceId workspaceId = pickOne(random, sampleWorkspaceIds);
      final ProjectId projectId = pickOne(random, sampleProjectIds);
      int expectedItemCount = 0;
      for (final Rule rule in rules) {
        final bool applies = doesScopeApply(
          scope: rule.scope,
          workspaceId: workspaceId,
          projectId: projectId,
        );
        if (rule.enabled && applies && !_hasBlankTitle(rule)) {
          expectedItemCount += 1;
        }
      }

      final String markdown = renderAgentsMarkdown(
        rules: rules,
        workspaceId: workspaceId,
        projectId: projectId,
      );

      int itemCount = 0;
      for (final String line in markdown.split('\n')) {
        expect(line, isNot(_emptyItemLine));
        if (line.startsWith(_itemPrefix)) {
          final String itemText = line.substring(_itemPrefix.length);
          expect(itemText.trimLeft(), itemText, reason: line);
          expect(itemText, isNotEmpty, reason: line);
          itemCount += 1;
        }
      }
      expect(itemCount, expectedItemCount);
    }
  });
}
