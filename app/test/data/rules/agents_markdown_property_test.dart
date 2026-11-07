import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/rules/agents_markdown.dart';

import '../../support/random_inputs.dart';
import '../../support/rule_saving_white_space_checks.dart';
import '../../support/rule_title_white_space_table.dart';

const String _rulesHeader = '# Rules\n\n';
const String _titleBullet = '- ';
const String _detailIndent = '  ';
const List<String> _sentenceEndings = <String>['.', '!', '?'];
const List<String> _lineBreaks = <String>['\n', '\r', '\r\n'];
const int _mostDetailParts = 6;
const int _mostRules = 6;

String _randomDetails(Random random, RuleTitleWhiteSpaceTable table) {
  final int partCount = random.nextInt(_mostDetailParts);
  final StringBuffer details = StringBuffer();
  for (int part = 0; part < partCount; part += 1) {
    final String piece = random.nextBool()
        ? pickOne(random, _lineBreaks)
        : table.randomExoticTitle(random);
    details.write(piece);
  }
  return details.toString();
}

List<Rule> _randomRules(Random random, RuleTitleWhiteSpaceTable table) {
  final int ruleCount = random.nextInt(_mostRules);
  return <Rule>[
    for (int index = 0; index < ruleCount; index += 1)
      Rule(
        id: RuleId('rule-$index'),
        title: random.nextBool()
            ? table.randomWhiteSpaceRun(random)
            : table.randomExoticTitle(random),
        details: _randomDetails(random, table),
        scope: const Scope.everywhere(),
        enabled: random.nextBool(),
        addedAt: galleryNow,
      ),
  ];
}

void main() {
  final RuleTitleWhiteSpaceTable table = readRuleTitleWhiteSpaceTable();

  test('test_render_rule_property_title_line_is_the_model_collapse', () {
    final Random random = seededRandom(60871);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String title = table.randomExoticTitle(random);

      final String markdown = renderRuleAlone(title: title, details: '');

      final String collapsed = table.collapseByModel(title);
      if (collapsed.isEmpty) {
        expect(markdown, isEmpty, reason: title.runes.toString());
        continue;
      }
      final bool endsSentence = _sentenceEndings.any(collapsed.endsWith);
      final String ending = endsSentence ? '' : '.';
      final String expected = '$_rulesHeader$_titleBullet$collapsed$ending\n';
      expect(markdown, expected, reason: title.runes.toString());
    }
  });

  test('test_render_rule_property_details_follow_rust_lines', () {
    final Random random = seededRandom(60872);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String details = _randomDetails(random, table);

      final String markdown = renderRuleAlone(title: 'Rule', details: details);

      final List<String> expectedLines = <String>['${_titleBullet}Rule.'];
      for (final String line in details.split('\n')) {
        final String trimmed = table.trimByModel(line);
        if (trimmed.isNotEmpty) {
          expectedLines.add('$_detailIndent$trimmed');
        }
      }
      final String expected = '$_rulesHeader${expectedLines.join('\n')}\n';
      expect(markdown, expected, reason: details.runes.toString());
    }
  });

  test('test_render_rule_property_lines_have_no_edge_white_space', () {
    final Random random = seededRandom(60873);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String title = 'Rule${table.randomExoticTitle(random)}';
      final String details = _randomDetails(random, table);

      final String markdown = renderRuleAlone(title: title, details: details);

      final String body = markdown.substring(_rulesHeader.length);
      final List<String> lines = body.split('\n')..removeLast();
      for (final String line in lines) {
        final bool isTitle = line.startsWith(_titleBullet);
        final String prefix = isTitle ? _titleBullet : _detailIndent;
        final String text = line.substring(prefix.length);
        expect(line.startsWith(prefix), isTrue, reason: line);
        expect(text, isNotEmpty, reason: line);
        expect(table.trimByModel(text), text, reason: line.runes.toString());
      }
    }
  });

  test('test_render_agents_markdown_property_keeps_rust_titled_rules', () {
    final Random random = seededRandom(60874);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Rule> rules = _randomRules(random, table);

      final String markdown = renderAgentsMarkdown(
        rules: rules,
        workspaceId: const WorkspaceId('workspace'),
        projectId: const ProjectId('project'),
      );

      final StringBuffer expected = StringBuffer();
      for (final Rule rule in rules) {
        final bool hasTitle = table.trimByModel(rule.title).isNotEmpty;
        if (rule.enabled && hasTitle) {
          final String alone = renderRuleAlone(
            title: rule.title,
            details: rule.details,
          );
          expected.write(alone.substring(_rulesHeader.length));
        }
      }
      final String expectedMarkdown = expected.isEmpty
          ? ''
          : '$_rulesHeader$expected';
      expect(markdown, expectedMarkdown);
    }
  });
}
