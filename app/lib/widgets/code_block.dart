import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';

enum LineChange {
  unchanged(null),
  added(AppColors.actionTint),
  removed(AppColors.dangerTint);

  const LineChange(this.background);

  final Color? background;
}

final class CodeBlockLine {
  const CodeBlockLine(this.text) : change = LineChange.unchanged;

  const CodeBlockLine.added(this.text) : change = LineChange.added;

  const CodeBlockLine.removed(this.text) : change = LineChange.removed;

  final String text;
  final LineChange change;
}

final BoxDecoration _codePanelDecoration = BoxDecoration(
  color: AppColors.sunken,
  border: Border.all(color: AppColors.line),
  borderRadius: BorderRadius.circular(AppRadii.panel),
);

class CodePanel extends StatelessWidget {
  const CodePanel({required this.lines, super.key});

  final List<Widget> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.space3),
      decoration: _codePanelDecoration,
      child: LayoutBuilder(builder: _buildScrollingLines),
    );
  }

  Widget _buildScrollingLines(BuildContext context, BoxConstraints limits) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: limits.maxWidth),
        child: IntrinsicWidth(
          child: DefaultTextStyle(
            style: AppTextStyles.code,
            softWrap: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: lines,
            ),
          ),
        ),
      ),
    );
  }
}

class CodeBlock extends StatelessWidget {
  const CodeBlock({required this.lines, super.key});

  final List<CodeBlockLine> lines;

  @override
  Widget build(BuildContext context) {
    return CodePanel(
      lines: <Widget>[
        for (final CodeBlockLine line in lines)
          Container(
            color: line.change.background,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space4),
            child: Text(line.text),
          ),
      ],
    );
  }
}

class WrappedCodeBlock extends StatelessWidget {
  const WrappedCodeBlock({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space4,
        vertical: AppSpacing.space3,
      ),
      decoration: _codePanelDecoration,
      child: Text(text, style: AppTextStyles.code),
    );
  }
}
