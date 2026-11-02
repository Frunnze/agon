import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/theme/app_spacing.dart';

const double _cursorWidthShare = 0.5;
const double _cursorHeightShare = 1.1;
const double _visibleUntil = 0.5;

class BlinkingCursor extends StatefulWidget {
  const BlinkingCursor({super.key});

  @override
  State<BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: AppDurations.cursorBlink,
  );

  @override
  void initState() {
    super.initState();
    _blink.repeat().ignore();
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle style = DefaultTextStyle.of(context).style;
    final double fontSize = style.fontSize ?? AppSpacing.space4;

    return AnimatedBuilder(
      animation: _blink,
      builder: _buildBlock,
      child: Container(
        margin: const EdgeInsets.only(left: AppSpacing.space1),
        width: fontSize * _cursorWidthShare,
        height: fontSize * _cursorHeightShare,
        color: style.color,
      ),
    );
  }

  Widget _buildBlock(BuildContext context, Widget? block) {
    final bool isVisible = _blink.value < _visibleUntil;

    return Opacity(opacity: isVisible ? 1 : 0, child: block);
  }
}
