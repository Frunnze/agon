import 'dart:convert';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/rules/scope_rules.dart';

const String _rulesHeader = '# Rules\n\n';
const String _titleBullet = '- ';
const String _detailIndent = '  ';
const List<String> _sentenceEndings = <String>['.', '!', '?'];
final RegExp _whitespaceRun = RegExp(r'\s+');

String renderAgentsMarkdown({
  required List<Rule> rules,
  required WorkspaceId workspaceId,
  required ProjectId projectId,
}) {
  final StringBuffer ruleSections = StringBuffer();

  for (final Rule rule in rules) {
    final bool applies = doesScopeApply(
      scope: rule.scope,
      workspaceId: workspaceId,
      projectId: projectId,
    );
    if (rule.enabled && applies) {
      ruleSections.write(_renderRule(rule));
    }
  }

  if (ruleSections.isEmpty) {
    return '';
  }
  return '$_rulesHeader$ruleSections';
}

String _renderRule(Rule rule) {
  final String title = rule.title.trim().split(_whitespaceRun).join(' ');
  final bool endsSentence = _sentenceEndings.any(title.endsWith);
  final String titleLine = endsSentence
      ? '$_titleBullet$title'
      : '$_titleBullet$title.';
  final List<String> lines = <String>[titleLine];

  for (final String detailLine in LineSplitter.split(rule.details)) {
    final String trimmedLine = detailLine.trim();
    if (trimmedLine.isNotEmpty) {
      lines.add('$_detailIndent$trimmedLine');
    }
  }

  return '${lines.join('\n')}\n';
}
