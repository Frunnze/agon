import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/theme/app_theme.dart';

import 'random_inputs.dart';

const double phoneWidth = 390;
const double phoneHeight = 844;
const double desktopWidth = 1440;
const double desktopHeight = 900;
const double narrowestWidth = 320;
const double widestWidth = 1600;

void useViewSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget wrapInApp(Widget child) {
  return MaterialApp(
    theme: buildAppTheme(),
    home: Scaffold(body: child),
  );
}

Future<void> pumpScrollableAtWidth(
  WidgetTester tester, {
  required double width,
  required Widget child,
}) async {
  useViewSize(tester, Size(width, desktopHeight));
  await tester.pumpWidget(wrapInApp(SingleChildScrollView(child: child)));
  await tester.pump();
}

Future<void> expectRendersAtRandomWidths(
  WidgetTester tester, {
  required int seed,
  required Widget Function(Random random) buildChild,
}) async {
  final Random random = seededRandom(seed);

  for (int i = 0; i < widgetPropertyIterations; i += 1) {
    final double width = randomWidth(
      random,
      least: narrowestWidth,
      most: widestWidth,
    );
    await pumpScrollableAtWidth(
      tester,
      width: width,
      child: buildChild(random),
    );
    expect(tester.takeException(), isNull, reason: 'width $width');
  }
}
