import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/widgets/blinking_cursor.dart';
import 'package:agent_orchestration/widgets/code_block.dart';

const String _timeSeparator = ' ';

enum LineTone {
  normal(AppColors.ink),
  danger(AppColors.danger);

  const LineTone(this.color);

  final Color color;
}

enum CursorVisibility { hidden, shown }

final class LogBlockLine {
  const LogBlockLine({
    required this.time,
    required this.text,
    required this.tone,
  });

  final String time;
  final String text;
  final LineTone tone;
}

class LogBlock extends StatelessWidget {
  const LogBlock({required this.lines, required this.cursor, super.key});

  final List<LogBlockLine> lines;
  final CursorVisibility cursor;

  @override
  Widget build(BuildContext context) {
    final List<Widget> lineWidgets = <Widget>[];
    for (int index = 0; index < lines.length; index += 1) {
      final bool isLastLine = index == lines.length - 1;
      final bool showsCursor = isLastLine && cursor == CursorVisibility.shown;
      lineWidgets.add(
        _LogLineText(
          line: lines[index],
          cursor: showsCursor
              ? CursorVisibility.shown
              : CursorVisibility.hidden,
        ),
      );
    }

    return Semantics(
      liveRegion: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxHeight: AppSizes.logMaximumHeight,
        ),
        child: SingleChildScrollView(
          reverse: true,
          child: CodePanel(lines: lineWidgets),
        ),
      ),
    );
  }
}

class _LogLineText extends StatelessWidget {
  const _LogLineText({required this.line, required this.cursor});

  final LogBlockLine line;
  final CursorVisibility cursor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space4),
      child: Text.rich(
        TextSpan(
          children: <InlineSpan>[
            TextSpan(
              text: line.time,
              style: const TextStyle(color: AppColors.inkMuted),
            ),
            const WidgetSpan(child: SizedBox(width: AppSpacing.space2)),
            const TextSpan(text: _timeSeparator),
            TextSpan(
              text: line.text,
              style: TextStyle(color: line.tone.color),
            ),
            if (cursor == CursorVisibility.shown)
              const WidgetSpan(child: BlinkingCursor()),
          ],
        ),
      ),
    );
  }
}
