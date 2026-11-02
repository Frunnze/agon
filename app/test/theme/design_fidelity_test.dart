import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/screens/projects/workspace_link.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/shell/side_rail.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_theme.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/theme/layout_size.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

import '../support/app_harness.dart';
import '../support/random_inputs.dart';
import '../support/widget_harness.dart';

const double _cssButtonBoxHeight =
    AppFontSizes.body * AppLineHeights.body +
    (AppSpacing.space2 + AppBorders.thin) * 2;
const double _shortestWindowHeight = 480;
const double _tallestWindowHeight = 1400;

Future<void> _pumpButtonAtWidth(WidgetTester tester, double width) async {
  useViewSize(tester, Size(width, desktopHeight));
  await tester.pumpWidget(
    wrapInApp(
      Center(
        child: AppButton.primary(label: 'New job', onPressed: () {}),
      ),
    ),
  );
}

void main() {
  test('test_build_app_theme_property_standard_density_on_every_platform', () {
    for (final TargetPlatform platform in TargetPlatform.values) {
      debugDefaultTargetPlatformOverride = platform;
      final ThemeData theme = buildAppTheme();
      debugDefaultTargetPlatformOverride = null;

      expect(theme.visualDensity, VisualDensity.standard, reason: '$platform');
    }
  });

  testWidgets('test_app_button_property_height_matches_design_on_macos', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(7401);
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = randomWidth(
        random,
        least: narrowestWidth,
        most: widestWidth,
      );
      await _pumpButtonAtWidth(tester, width);

      final double minimumHeight = LayoutSize.forWidth(width).isLarge
          ? AppSizes.controlHeightCompact
          : AppSizes.controlHeight;
      final double expectedHeight = max(minimumHeight, _cssButtonBoxHeight);
      final double buttonHeight = tester
          .getSize(find.byType(AppButton))
          .height;
      expect(buttonHeight, expectedHeight, reason: 'width $width');
    }

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('test_app_button_property_label_uses_the_theme_body_font', (
    WidgetTester tester,
  ) async {
    for (final TargetPlatform platform in TargetPlatform.values) {
      debugDefaultTargetPlatformOverride = platform;
      await tester.pumpWidget(const SizedBox());
      await _pumpButtonAtWidth(tester, desktopWidth);

      final BuildContext context = tester.element(find.byType(AppButton));
      final String? bodyFontFamily = Theme.of(context)
          .textTheme
          .bodyLarge
          ?.fontFamily;
      final RichText label = tester.widget<RichText>(
        find.descendant(
          of: find.byType(AppButton),
          matching: find.byType(RichText),
        ),
      );
      expect(
        label.text.style?.fontFamily,
        bodyFontFamily,
        reason: '$platform',
      );
      expect(label.text.style?.fontWeight, FontWeight.w700);
    }

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('test_side_rail_property_fills_the_window_height', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(7402);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = randomWidth(
        random,
        least: LayoutSize.mediumMinimumWidth,
        most: widestWidth,
      );
      final double height = randomWidth(
        random,
        least: _shortestWindowHeight,
        most: _tallestWindowHeight,
      );
      await pumpApp(
        tester,
        size: Size(width, height),
        route: const SectionRoute(AppSection.tasks),
        dependencies: buildGalleryDependencies(),
      );

      final Rect railArea = tester.getRect(find.byType(SideRail));
      expect(railArea.top, 0, reason: '$width x $height');
      expect(railArea.height, height, reason: '$width x $height');
    }
  });

  testWidgets('test_quiet_links_property_labels_use_the_theme_body_font', (
    WidgetTester tester,
  ) async {
    final Map<String, Widget> quietLinks = <String, Widget>{
      'Your devices': BackLinkButton(
        link: BackLink(label: 'Your devices', onPressed: () {}),
      ),
      'acme workspace': WorkspaceLinkButton(
        workspaceName: 'acme',
        onPressed: () {},
      ),
    };

    for (final TargetPlatform platform in TargetPlatform.values) {
      for (final MapEntry<String, Widget> quietLink in quietLinks.entries) {
        debugDefaultTargetPlatformOverride = platform;
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(wrapInApp(Center(child: quietLink.value)));

        final BuildContext context = tester.element(find.text(quietLink.key));
        final String? bodyFontFamily = Theme.of(context)
            .textTheme
            .bodyLarge
            ?.fontFamily;
        final RichText label = tester.widget<RichText>(
          find.descendant(
            of: find.text(quietLink.key),
            matching: find.byType(RichText),
          ),
        );
        final String reason = '${quietLink.key} on $platform';
        expect(label.text.style?.fontFamily, bodyFontFamily, reason: reason);
        expect(label.text.style?.fontSize, AppFontSizes.small, reason: reason);
      }
    }

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('test_app_button_property_border_adds_to_the_padding', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(7403);
    const double sidePadding = AppSpacing.space4 + AppBorders.thin;

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String label = 'Label ${random.nextInt(100000)}';
      useViewSize(tester, const Size(desktopWidth, desktopHeight));
      await tester.pumpWidget(
        wrapInApp(
          Center(
            child: AppButton.secondary(label: label, onPressed: () {}),
          ),
        ),
      );

      final double buttonWidth = tester.getSize(find.byType(AppButton)).width;
      final double labelWidth = tester.getSize(find.text(label)).width;
      expect(
        buttonWidth - labelWidth,
        closeTo(sidePadding * 2, 0.5),
        reason: label,
      );
    }
  });
}
