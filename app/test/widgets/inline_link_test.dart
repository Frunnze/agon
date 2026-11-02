import 'dart:math';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/widgets/inline_link.dart';

import '../support/random_inputs.dart';
import '../support/widget_harness.dart';

const String _linkLabel = 'Your devices';
const List<Color> _surroundingColors = <Color>[
  AppColors.ink,
  AppColors.inkMuted,
  AppColors.attention,
];
const List<double> _surroundingSizes = <double>[12, 14, 16, 20];

void main() {
  testWidgets('test_inline_link_property_inherits_the_surrounding_text', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(7311);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Color color = pickOne(random, _surroundingColors);
      final double fontSize = pickOne(random, _surroundingSizes);
      int tapCount = 0;
      await tester.pumpWidget(
        wrapInApp(
          DefaultTextStyle(
            style: TextStyle(color: color, fontSize: fontSize),
            child: InlineLink(
              label: _linkLabel,
              onPressed: () => tapCount += 1,
            ),
          ),
        ),
      );

      final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
        find.text(_linkLabel),
      );
      final TextStyle shownStyle = paragraph.text.style!;
      expect(shownStyle.color, color);
      expect(shownStyle.fontSize, fontSize);
      expect(shownStyle.decoration, TextDecoration.underline);

      await tester.tap(find.text(_linkLabel));
      expect(tapCount, 1);
    }
  });
}
