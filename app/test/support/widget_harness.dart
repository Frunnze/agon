import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/theme/app_theme.dart';
import 'package:agent_orchestration/theme/apply_layout_density.dart';
import 'package:agent_orchestration/theme/layout_density.dart';
import 'package:agent_orchestration/theme/layout_size.dart';

import 'random_inputs.dart';

const double phoneWidth = 390;
const double phoneHeight = 844;
const double desktopWidth = 1440;
const double desktopHeight = 900;
const double narrowestWidth = 320;
const double widestWidth = 1600;
const TargetPlatform phonePlatform = TargetPlatform.android;
const TargetPlatform desktopPlatform = TargetPlatform.macOS;

TargetPlatform platformMeantByWidth(double windowWidth) {
  if (LayoutSize.forWidth(windowWidth).isCompact) {
    return phonePlatform;
  }
  return desktopPlatform;
}

LayoutDensity densityMeantByWidth(double windowWidth) {
  final TargetPlatform platform = platformMeantByWidth(windowWidth);
  return LayoutDensity.forPlatform(platform);
}

void useViewSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget wrapInApp(Widget child, {required TargetPlatform platform}) {
  final ThemeData platformTheme = buildAppTheme().copyWith(platform: platform);

  return MaterialApp(
    theme: platformTheme,
    themeAnimationStyle: AnimationStyle.noAnimation,
    builder: applyLayoutDensity,
    home: Scaffold(body: child),
  );
}

Future<void> pumpScrollableOnPlatform(
  WidgetTester tester, {
  required double width,
  required TargetPlatform platform,
  required Widget child,
}) async {
  final Widget scrollable = SingleChildScrollView(child: child);
  useViewSize(tester, Size(width, desktopHeight));
  await tester.pumpWidget(wrapInApp(scrollable, platform: platform));
  await tester.pump();
}

Future<void> pumpScrollableAtWidth(
  WidgetTester tester, {
  required double width,
  required Widget child,
}) async {
  await pumpScrollableOnPlatform(
    tester,
    width: width,
    platform: platformMeantByWidth(width),
    child: child,
  );
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
