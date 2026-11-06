import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../support/app_harness.dart';
import '../../support/builder_harness.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';

const double _narrowestDesktopWidth = 1000;
const double _widestDesktopWidth = 2200;
const double _narrowestOneRowWidth = 1300;
const double _shortestDesktopHeight = 700;
const double _tallestDesktopHeight = 1400;
const double _desktopHeightSpan =
    _tallestDesktopHeight - _shortestDesktopHeight;
const double _smallestDesktopCanvasShare = 0.65;
const double _smallestPhoneCanvasShare = 0.5;

Size _pickDesktopSize(Random random) {
  final double width = randomWidth(
    random,
    least: _narrowestDesktopWidth,
    most: _widestDesktopWidth,
  );
  final double heightAboveShortest = random.nextDouble() * _desktopHeightSpan;
  final double height = _shortestDesktopHeight + heightAboveShortest;

  return Size(width, height);
}

double _measureCanvasShareOfPage(WidgetTester tester) {
  final Rect pageBody = tester.getRect(find.byType(BuilderPageLayout));
  final Rect canvas = tester.getRect(find.byType(CanvasFrame));

  return canvas.height / pageBody.height;
}

Future<void> _openManualBuilder(WidgetTester tester, Size size) async {
  final AppNavigation navigation = await pumpApp(
    tester,
    size: size,
    route: workflowsSectionRoute,
    dependencies: buildGalleryDependencies(),
  );
  navigation.openRoute(const ManualWorkflowRoute());
  await pumpFrames(tester);
}

void main() {
  testWidgets(
    'test_builder_page_layout_property_drafted_canvas_fills_desktop',
    (WidgetTester tester) async {
      final Random random = seededRandom(9101);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final Size size = _pickDesktopSize(random);
        await openPipelineBuilder(
          tester,
          size: size,
          dependencies: buildGalleryDependencies(),
        );

        expect(
          _measureCanvasShareOfPage(tester),
          greaterThanOrEqualTo(_smallestDesktopCanvasShare),
          reason: '$size',
        );
      }
    },
  );

  testWidgets(
    'test_builder_page_layout_property_manual_canvas_fills_desktop',
    (WidgetTester tester) async {
      final Random random = seededRandom(9102);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final Size size = _pickDesktopSize(random);
        await _openManualBuilder(tester, size);

        expect(
          _measureCanvasShareOfPage(tester),
          greaterThanOrEqualTo(_smallestDesktopCanvasShare),
          reason: '$size',
        );
      }
    },
  );

  testWidgets('phone builders leave the canvas at least half the page', (
    WidgetTester tester,
  ) async {
    await openPipelineBuilder(
      tester,
      size: phoneSize,
      dependencies: buildGalleryDependencies(),
    );
    expect(
      _measureCanvasShareOfPage(tester),
      greaterThanOrEqualTo(_smallestPhoneCanvasShare),
    );

    await _openManualBuilder(tester, phoneSize);
    expect(
      _measureCanvasShareOfPage(tester),
      greaterThanOrEqualTo(_smallestPhoneCanvasShare),
    );
  });

  testWidgets('test_builder_toolbar_property_one_row_without_ask_field', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9103);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Size size = Size(
        randomWidth(
          random,
          least: _narrowestOneRowWidth,
          most: _widestDesktopWidth,
        ),
        _tallestDesktopHeight,
      );
      await openPipelineBuilder(
        tester,
        size: size,
        dependencies: buildGalleryDependencies(),
      );

      final Rect toolbar = tester.getRect(find.byType(BuilderToolbar));
      final Rect addAgentButton = tester.getRect(
        find.widgetWithText(AppButton, addAgentLabel),
      );
      expect(toolbar.height, addAgentButton.height, reason: '$size');
      expect(
        find.descendant(
          of: find.byType(BuilderToolbar),
          matching: find.byType(TextField),
        ),
        findsNothing,
      );
    }
  });

  testWidgets('test_builder_toolbar_property_ask_button_ends_its_row', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9104);

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
          onAgentAdded: () {},
          onPersonStepAdded: () {},
          onChatOpened: () {},
        ),
      );

      final Rect toolbar = tester.getRect(find.byType(BuilderToolbar));
      final Rect addButtons = tester.getRect(find.byType(AddStepButtons));
      final Rect askButton = tester.getRect(
        find.widgetWithText(AppButton, askAnAgentLabel),
      );
      expect(tester.takeException(), isNull, reason: 'width $width');
      expect(askButton.right, lessThanOrEqualTo(toolbar.right + 0.5));
      final bool sharesTheRow = askButton.top < addButtons.bottom;
      if (sharesTheRow) {
        expect(askButton.right, closeTo(toolbar.right, 0.5), reason: '$width');
      } else {
        expect(askButton.top, greaterThan(addButtons.bottom), reason: '$width');
      }
    }
  });

  testWidgets('test_builder_toolbar_property_each_button_calls_its_own', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9105);
    final List<String> labels = <String>[
      addAgentLabel,
      addPersonStepLabel,
      askAnAgentLabel,
    ];

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Map<String, int> pressCounts = <String, int>{
        for (final String label in labels) label: 0,
      };
      final double width = randomWidth(
        random,
        least: narrowestWidth,
        most: widestWidth,
      );
      await pumpScrollableAtWidth(
        tester,
        width: width,
        child: BuilderToolbar(
          onAgentAdded: () => pressCounts[addAgentLabel] =
              pressCounts[addAgentLabel]! + 1,
          onPersonStepAdded: () => pressCounts[addPersonStepLabel] =
              pressCounts[addPersonStepLabel]! + 1,
          onChatOpened: () => pressCounts[askAnAgentLabel] =
              pressCounts[askAnAgentLabel]! + 1,
        ),
      );
      final String pressed = pickOne(random, labels);

      await tester.tap(find.widgetWithText(AppButton, pressed));
      await tester.pump();

      for (final String label in labels) {
        final int expectedCount = label == pressed ? 1 : 0;
        expect(pressCounts[label], expectedCount, reason: label);
      }
    }
  });
}
