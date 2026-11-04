import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/empty_state.dart';

import '../support/random_inputs.dart';
import '../support/shown_text_metrics.dart';
import '../support/widget_harness.dart';

const String _actionLabel = 'New skill';
const TextStyle _titleLeading = TextStyle(
  fontSize: AppFontSizes.heading,
  height: AppLineHeights.body,
);
const List<String> _shortTitles = <String>[
  'No runners yet',
  'Nothing logged yet',
  'No skills yet',
];

Widget? _buildRandomAction(Random random) {
  final bool hasAction = random.nextBool();
  if (!hasAction) {
    return null;
  }
  return AppButton.primary(label: _actionLabel, onPressed: () {});
}

void main() {
  testWidgets('test_empty_state_property_shows_an_action_only_when_given', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(7301);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String title = 'Title ${randomWordPhrase(random)}';
      final String message = 'Message ${randomWordPhrase(random)}';
      final Widget? action = _buildRandomAction(random);

      await tester.pumpWidget(
        wrapInApp(
          EmptyState(title: title, message: message, action: action),
          platform: desktopPlatform,
        ),
      );

      expect(find.text(title), findsOneWidget);
      expect(find.text(message), findsOneWidget);
      expect(
        find.byType(AppButton),
        action == null ? findsNothing : findsOneWidget,
      );
    }
  });

  testWidgets('test_empty_state_property_renders_at_any_width', (
    WidgetTester tester,
  ) async {
    await expectRendersAtRandomWidths(
      tester,
      seed: 7302,
      buildChild: (Random random) => EmptyState(
        title: randomText(random),
        message: randomText(random),
        action: _buildRandomAction(random),
      ),
    );
  });

  testWidgets('test_empty_state_property_title_line_uses_body_leading', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(7303);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String title = pickOne(random, _shortTitles);
      final double width = randomWidth(
        random,
        least: narrowestWidth,
        most: widestWidth,
      );
      await pumpScrollableAtWidth(
        tester,
        width: width,
        child: EmptyState(
          title: title,
          message: randomWordPhrase(random),
          action: _buildRandomAction(random),
        ),
      );

      final double titleHeight = tester.getSize(find.text(title)).height;
      final double titleLineHeight = shownLineHeightAtWidth(
        style: _titleLeading,
        windowWidth: width,
      );
      expect(titleHeight, titleLineHeight, reason: '$title at width $width');
    }
  });
}
