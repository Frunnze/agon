import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/theme/app_typography.dart';

import '../../support/app_harness.dart';
import '../../support/builder_harness.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';

const double _narrowestDesktopWidth = 1000;
const double _widestDesktopWidth = 2200;
const double _shortestDesktopHeight = 700;
const double _tallestDesktopHeight = 1400;
const double _desktopHeightSpan =
    _tallestDesktopHeight - _shortestDesktopHeight;
const double _smallestDesktopCanvasShare = 0.65;
const double _smallestPhoneCanvasShare = 0.5;
const double _singleSmallLineHeight =
    AppFontSizes.small * AppLineHeights.body;

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

  testWidgets('test_drafted_note_property_stays_one_line', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9103);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = randomWidth(
        random,
        least: narrowestWidth,
        most: widestWidth,
      );
      await pumpScrollableAtWidth(
        tester,
        width: width,
        child: const DraftedNote(),
      );

      expect(tester.takeException(), isNull, reason: 'width $width');
      expect(
        tester.getSize(find.byType(DraftedNote)).height,
        lessThanOrEqualTo(_singleSmallLineHeight),
        reason: 'width $width',
      );
      expect(find.text(draftedNoteTitle), findsOneWidget);
      expect(find.text(draftedNoteText), findsOneWidget);
    }
  });
}
