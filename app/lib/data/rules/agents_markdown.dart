import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/rules/scope_rules.dart';
import 'package:agent_orchestration/data/rules/unicode_white_space.dart';

const String _rulesHeader = '# Rules\n\n';
const String _titleBullet = '- ';
const String _detailIndent = '  ';
const String _lineBreak = '\n';
const List<String> _sentenceEndings = <String>['.', '!', '?'];

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
    final bool hasTitle = trimUnicodeWhiteSpace(rule.title).isNotEmpty;
    if (rule.enabled && applies && hasTitle) {
      ruleSections.write(_renderRule(rule));
    }
  }

  if (ruleSections.isEmpty) {
    return '';
  }
  return '$_rulesHeader$ruleSections';
}

String _renderRule(Rule rule) {
  final String title = collapseUnicodeWhiteSpace(rule.title);
  final bool endsSentence = _sentenceEndings.any(title.endsWith);
  final String titleLine = endsSentence
      ? '$_titleBullet$title'
      : '$_titleBullet$title.';
  final List<String> lines = <String>[titleLine];

  for (final String detailLine in rule.details.split(_lineBreak)) {
    final String trimmedLine = trimUnicodeWhiteSpace(detailLine);
    if (trimmedLine.isNotEmpty) {
      lines.add('$_detailIndent$trimmedLine');
    }
  }

  return '${lines.join('\n')}\n';
}
