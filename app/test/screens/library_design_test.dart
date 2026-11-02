import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/screens/workflow_builder/builder_toolbar.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/theme/field_padding.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/label_chip.dart';

import '../support/app_harness.dart';
import '../support/random_inputs.dart';
import '../support/widget_harness.dart';

const String _skillsNote =
    'Agents use automatic skills on their own when the work fits. Other '
    'skills run only when a task, job or workflow agent picks them.';
const String _agentsMarkdownNote =
    "A project's own AGENTS.md is kept. These rules are added on top.";

Future<double> _pumpAppAtRandomWidth(
  WidgetTester tester, {
  required Random random,
  required AppRoute route,
}) async {
  final double width = randomWidth(
    random,
    least: narrowestWidth,
    most: widestWidth,
  );
  await pumpApp(
    tester,
    size: Size(width, desktopHeight),
    route: route,
    dependencies: buildGalleryDependencies(),
  );
  return width;
}

void _expectBodySizedMutedText(WidgetTester tester, String text) {
  final TextStyle? style = tester.widget<Text>(find.text(text)).style;

  expect(style?.fontSize, AppFontSizes.body, reason: text);
  expect(style?.color, AppColors.inkMuted, reason: text);
}

void main() {
  testWidgets('test_skills_screen_property_note_is_body_sized_at_any_width', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9501);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpAppAtRandomWidth(
        tester,
        random: random,
        route: const SectionRoute(AppSection.skills),
      );

      _expectBodySizedMutedText(tester, _skillsNote);
    }
  });

  testWidgets('test_agents_markdown_preview_property_note_is_body_sized', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9502);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpAppAtRandomWidth(
        tester,
        random: random,
        route: const SectionRoute(AppSection.rules),
      );

      _expectBodySizedMutedText(tester, _agentsMarkdownNote);
    }
  });

  testWidgets('test_rules_screen_property_chips_sit_one_gap_under_details', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9503);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = await _pumpAppAtRandomWidth(
        tester,
        random: random,
        route: const SectionRoute(AppSection.rules),
      );
      final Rect details = tester.getRect(
        find.text('Open a pull request instead.'),
      );
      final Rect chip = tester.getRect(find.byType(LabelChip).first);

      expect(chip.top - details.bottom, AppSpacing.space1, reason: '$width');
    }
  });

  testWidgets('test_builder_toolbar_property_ask_button_matches_the_field', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9504);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = randomWidth(
        random,
        least: narrowestWidth,
        most: widestWidth,
      );
      await pumpScrollableAtWidth(
        tester,
        width: width,
        child: BuilderToolbar(
          askController: TextEditingController(),
          onAgentAdded: () {},
          onAsked: () {},
        ),
      );
      final double fieldHeight = tester.getSize(find.byType(TextField)).height;
      final double askHeight = tester
          .getSize(find.widgetWithText(AppButton, 'Ask'))
          .height;

      expect(askHeight, fieldHeight, reason: 'width $width');
    }
  });

  testWidgets('test_multi_line_field_padding_property_rows_match_design', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9505);
    const double lineHeight = AppFontSizes.body * AppLineHeights.body;
    const double frame = 2 * (AppSpacing.space2 + AppBorders.thin);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final int rows = 1 + random.nextInt(8);
      await pumpScrollableAtWidth(
        tester,
        width: desktopWidth,
        child: TextField(
          controller: TextEditingController(text: randomWordPhrase(random)),
          minLines: rows,
          maxLines: rows,
          decoration: const InputDecoration(
            contentPadding: multiLineFieldPadding,
          ),
        ),
      );

      expect(
        tester.getSize(find.byType(TextField)).height,
        rows * lineHeight + frame,
        reason: '$rows rows',
      );
    }
  });
}
