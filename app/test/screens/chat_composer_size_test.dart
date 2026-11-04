import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/chat/chat_composer.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/layout_density.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/forms/message_field.dart';

import '../support/chat_composer_harness.dart';
import '../support/message_keys.dart';
import '../support/random_inputs.dart';
import '../support/widget_harness.dart';

const int _mostLinesTried = 12;

Future<double> _measureFieldHoldingLines(
  WidgetTester tester,
  int lineCount,
) async {
  final String lines = List<String>.filled(lineCount, 'line').join('\n');
  await tester.enterText(findComposerField(), lines);
  await tester.pump();
  return tester.getSize(findComposerField()).height;
}

double _readScrollableLength(WidgetTester tester) {
  final ScrollableState scrollable = tester.state(
    find.descendant(
      of: findComposerField(),
      matching: find.byType(Scrollable),
    ),
  );
  return scrollable.position.maxScrollExtent;
}

void main() {
  testWidgets('test_chat_composer_property_one_line_matches_send_button', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(6105);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TargetPlatform platform = pickOne(random, everyPlatformList);
      final double width = randomWidth(
        random,
        least: narrowestWidth,
        most: widestWidth,
      );
      await pumpComposer(
        tester,
        platform: platform,
        width: width,
        sentMessages: <String>[],
      );
      await tester.enterText(findComposerField(), '');
      await tester.pump();

      final Rect field = tester.getRect(findComposerField());
      final Rect send = tester.getRect(
        find.descendant(
          of: find.byType(ChatComposer),
          matching: find.byType(AppButton),
        ),
      );
      final double controlHeight = AppSizes.controlHeightFor(
        LayoutDensity.forPlatform(platform),
      );
      final String reason = '$platform at width $width';
      expect(field.height, controlHeight, reason: reason);
      expect(send.height, controlHeight, reason: reason);
      expect(field.top, send.top, reason: reason);
    }
  });

  testWidgets(
    'test_chat_composer_property_grows_to_eight_lines_then_scrolls',
    (WidgetTester tester) async {
      for (final TargetPlatform platform in everyPlatformList) {
        await pumpComposer(
          tester,
          platform: platform,
          width: desktopWidth,
          sentMessages: <String>[],
        );
        final List<double> heights = <double>[];
        for (int lines = 1; lines <= _mostLinesTried; lines += 1) {
          heights.add(await _measureFieldHoldingLines(tester, lines));
        }

        final double lineHeight = heights[1] - heights[0];
        final double fullHeight = heights[messageFieldMaximumLines - 1];
        final String reason = '$platform heights $heights';
        expect(lineHeight, greaterThan(0), reason: reason);
        for (int index = 1; index < messageFieldMaximumLines; index += 1) {
          expect(
            heights[index] - heights[index - 1],
            closeTo(lineHeight, 0.01),
            reason: reason,
          );
        }
        for (final double height in heights.skip(messageFieldMaximumLines)) {
          expect(height, fullHeight, reason: reason);
        }
        expect(_readScrollableLength(tester), greaterThan(0), reason: reason);
      }
    },
  );
}
