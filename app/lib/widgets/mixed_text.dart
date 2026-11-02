import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/theme/app_typography.dart';

enum TextFace { body, monospace }

final class TextSegment {
  const TextSegment(this.text) : face = TextFace.body;

  const TextSegment.monospace(this.text) : face = TextFace.monospace;

  final String text;
  final TextFace face;
}

class MixedText extends StatelessWidget {
  const MixedText(this.segments, {super.key, this.style});

  final List<TextSegment> segments;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final List<InlineSpan> spans = <InlineSpan>[
      for (final TextSegment segment in segments)
        TextSpan(
          text: segment.text,
          style: segment.face == TextFace.monospace
              ? AppTextStyles.monospace
              : null,
        ),
    ];

    return Text.rich(TextSpan(children: spans), style: style);
  }
}
