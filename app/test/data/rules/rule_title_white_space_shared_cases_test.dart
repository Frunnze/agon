import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/rules/rule_titles.dart';
import 'package:agent_orchestration/data/rules/unicode_white_space.dart';

import '../../support/random_inputs.dart';
import '../../support/rule_saving_white_space_checks.dart';
import '../../support/rule_title_white_space_table.dart';

void _expectVerdict(String title, {required bool isBlank}) {
  final Matcher verdict = isBlank ? throwsArgumentError : returnsNormally;
  final String reason = title.runes.toString();
  expect(() => requireRuleTitle(title), verdict, reason: reason);
}

void main() {
  final RuleTitleWhiteSpaceTable table = readRuleTitleWhiteSpaceTable();

  test('test_require_rule_title_property_agrees_with_shared_table', () {
    for (final RuleTitleWhiteSpaceCase sharedCase in table.cases) {
      _expectVerdict(sharedCase.title, isBlank: sharedCase.isBlank);
    }
  });

  test('test_require_rule_title_property_refuses_exactly_model_blanks', () {
    final Random random = seededRandom(60831);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String title = table.randomExoticTitle(random);

      final bool isBlankByModel = table.trimByModel(title).isEmpty;

      _expectVerdict(title, isBlank: isBlankByModel);
    }
  });

  test('test_require_rule_title_property_shared_titles_ignore_padding', () {
    final Random random = seededRandom(60832);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RuleTitleWhiteSpaceCase sharedCase = pickOne(random, table.cases);
      final String leading = table.randomWhiteSpaceRun(random);
      final String trailing = table.randomWhiteSpaceRun(random);

      final String padded = '$leading${sharedCase.title}$trailing';

      _expectVerdict(padded, isBlank: sharedCase.isBlank);
    }
  });

  test('test_render_agents_markdown_property_agrees_with_shared_table', () {
    for (final RuleTitleWhiteSpaceCase sharedCase in table.cases) {
      final String markdown = renderRuleAlone(
        title: sharedCase.title,
        details: sharedCase.details,
      );

      expect(
        markdown,
        sharedCase.markdown,
        reason: sharedCase.title.runes.toString(),
      );
    }
  });

  test(
    'test_render_agents_markdown_property_shared_titles_ignore_padding',
    () {
      final Random random = seededRandom(60833);

      for (int i = 0; i < propertyIterations; i += 1) {
        final RuleTitleWhiteSpaceCase sharedCase = pickOne(
          random,
          table.cases,
        );
        final String leading = table.randomWhiteSpaceRun(random);
        final String trailing = table.randomWhiteSpaceRun(random);

        final String markdown = renderRuleAlone(
          title: '$leading${sharedCase.title}$trailing',
          details: sharedCase.details,
        );

        expect(markdown, sharedCase.markdown);
      }
    },
  );

  test(
    'test_collapse_unicode_white_space_property_agrees_with_shared_table',
    () {
      for (final RuleTitleWhiteSpaceCase sharedCase in table.cases) {
        final String collapsed = collapseUnicodeWhiteSpace(sharedCase.title);
        final String trimmed = trimUnicodeWhiteSpace(sharedCase.title);

        expect(collapsed, sharedCase.collapsed);
        expect(trimmed.isEmpty, sharedCase.isBlank);
      }
    },
  );
}
