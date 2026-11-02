import 'package:flutter/widgets.dart';
import 'package:markdown/markdown.dart' as markdown;

import 'package:agent_orchestration/screens/files/text_lines.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/code_block.dart';
import 'package:agent_orchestration/widgets/gaps.dart';

const String _bulletMarker = '•';
const String _softLineBreak = '\n';
const String _space = ' ';
const String _listStartAttribute = 'start';
const int _firstListNumber = 1;
const String _titleTag = 'h1';
const Set<String> _subheadingTags = <String>{'h2', 'h3', 'h4', 'h5', 'h6'};
const String _paragraphTag = 'p';
const String _orderedListTag = 'ol';
const Set<String> _listTags = <String>{'ul', _orderedListTag};
const String _codeBlockTag = 'pre';
const String _quoteTag = 'blockquote';
const String _ruleTag = 'hr';
const String _tableTag = 'table';
const String _inlineCodeTag = 'code';
const String _emphasisTag = 'em';
const String _strongTag = 'strong';
const String _linkTag = 'a';
const String _lineBreakTag = 'br';
const Set<String> _blockTags = <String>{
  _titleTag,
  ..._subheadingTags,
  _paragraphTag,
  ..._listTags,
  _codeBlockTag,
  _quoteTag,
  _ruleTag,
  _tableTag,
};
const TextStyle _inlineCodeStyle = TextStyle(
  fontFamily: AppFontFamilies.monospace,
  fontFamilyFallback: AppFontFamilies.monospaceFallback,
  fontSize: AppFontSizes.small,
  backgroundColor: AppColors.raised,
);
const TextStyle _emphasisStyle = TextStyle(fontStyle: FontStyle.italic);
const TextStyle _strongStyle = TextStyle(fontWeight: FontWeight.w700);
const TextStyle _linkStyle = TextStyle(decoration: TextDecoration.underline);

class MarkdownView extends StatelessWidget {
  const MarkdownView({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final List<markdown.Node> nodes = markdown.Document(encodeHtml: false)
        .parse(text);

    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSizes.measure),
        child: _buildFlow(nodes),
      ),
    );
  }
}

Widget _buildFlow(List<markdown.Node> nodes) {
  final List<Widget> blocks = <Widget>[];
  final List<markdown.Node> inlineRun = <markdown.Node>[];

  for (final markdown.Node node in nodes) {
    if (_isBlock(node)) {
      _addParagraph(inlineRun, blocks);
      blocks.add(_buildBlock(node as markdown.Element));
    } else {
      inlineRun.add(node);
    }
  }
  _addParagraph(inlineRun, blocks);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: spaceVertically(blocks, AppSpacing.space3),
  );
}

bool _isBlock(markdown.Node node) {
  return node is markdown.Element && _blockTags.contains(node.tag);
}

void _addParagraph(List<markdown.Node> inlineRun, List<Widget> blocks) {
  if (inlineRun.isEmpty) {
    return;
  }
  blocks.add(_buildRichText(inlineRun, AppTextStyles.body));
  inlineRun.clear();
}

Widget _buildBlock(markdown.Element element) {
  final String tag = element.tag;
  final List<markdown.Node> children =
      element.children ?? const <markdown.Node>[];

  if (tag == _titleTag) {
    return Semantics(
      header: true,
      child: _buildRichText(children, AppTextStyles.heading),
    );
  }
  if (_subheadingTags.contains(tag)) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.space3),
      child: Semantics(
        header: true,
        child: _buildRichText(children, AppTextStyles.bodyBold),
      ),
    );
  }
  if (tag == _paragraphTag) {
    return _buildRichText(children, AppTextStyles.body);
  }
  if (_listTags.contains(tag)) {
    return _buildList(element);
  }
  if (tag == _codeBlockTag) {
    return _buildCodeBlock(element.textContent);
  }
  if (tag == _quoteTag) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.space5),
      child: _buildFlow(children),
    );
  }
  if (tag == _ruleTag) {
    return Container(height: AppBorders.thin, color: AppColors.line);
  }
  return Text(element.textContent);
}

Widget _buildCodeBlock(String code) {
  return CodePanel(
    lines: <Widget>[
      for (final String line in splitTextLines(code))
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space4),
          child: Text(line),
        ),
    ],
  );
}

Widget _buildList(markdown.Element list) {
  final bool isOrdered = list.tag == _orderedListTag;
  final int firstNumber =
      int.tryParse(list.attributes[_listStartAttribute] ?? '') ??
      _firstListNumber;
  final List<markdown.Node> items = list.children ?? const <markdown.Node>[];
  final List<Widget> rows = <Widget>[];

  for (int index = 0; index < items.length; index += 1) {
    final markdown.Node item = items[index];
    final List<markdown.Node> content = item is markdown.Element
        ? item.children ?? const <markdown.Node>[]
        : <markdown.Node>[item];
    final String marker = isOrdered
        ? '${firstNumber + index}.'
        : _bulletMarker;
    rows.add(
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(width: AppSpacing.space5, child: Text(marker)),
          Expanded(child: _buildFlow(content)),
        ],
      ),
    );
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: spaceVertically(rows, AppSpacing.space1),
  );
}

Widget _buildRichText(List<markdown.Node> nodes, TextStyle style) {
  return Text.rich(
    TextSpan(
      children: <InlineSpan>[
        for (final markdown.Node node in nodes) _buildSpan(node),
      ],
    ),
    style: style,
  );
}

InlineSpan _buildSpan(markdown.Node node) {
  if (node is! markdown.Element) {
    return TextSpan(text: node.textContent.replaceAll(_softLineBreak, _space));
  }

  final List<InlineSpan> children = <InlineSpan>[
    for (final markdown.Node child in node.children ?? const <markdown.Node>[])
      _buildSpan(child),
  ];
  switch (node.tag) {
    case _inlineCodeTag:
      return TextSpan(text: node.textContent, style: _inlineCodeStyle);
    case _emphasisTag:
      return TextSpan(children: children, style: _emphasisStyle);
    case _strongTag:
      return TextSpan(children: children, style: _strongStyle);
    case _linkTag:
      return TextSpan(children: children, style: _linkStyle);
    case _lineBreakTag:
      return const TextSpan(text: _softLineBreak);
    default:
      return TextSpan(children: children);
  }
}
