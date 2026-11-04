import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/icons/app_icon.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/theme/layout_density.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../support/random_inputs.dart';
import '../support/widget_harness.dart';

const double _widestWindowWidth = 2200;
const double _denseControlHeight = 32;
const double _touchControlHeight = 44;
const double _denseIconExtent = 16;
const double _touchIconExtent = 20;
const double _denseBodyFontSize = 14;
const double _touchBodyFontSize = 16;
const String _sampleText = 'Ship';

const List<TargetPlatform> _computerPlatforms = <TargetPlatform>[
  TargetPlatform.macOS,
  TargetPlatform.windows,
  TargetPlatform.linux,
];
const List<TargetPlatform> _touchPlatforms = <TargetPlatform>[
  TargetPlatform.iOS,
  TargetPlatform.android,
];

typedef _ShownTextSize = ({TextStyle style, double touch, double dense});
typedef _DeviceWindow = ({TargetPlatform platform, double width});

const List<_ShownTextSize> _shownTextSizes = <_ShownTextSize>[
  (style: AppTextStyles.caption, touch: 12, dense: 12),
  (style: AppTextStyles.small, touch: 14, dense: 13),
  (style: AppTextStyles.body, touch: 16, dense: 14),
  (style: AppTextStyles.heading, touch: 20, dense: 17),
  (style: AppTextStyles.pageTitle, touch: 28, dense: 22),
];

_DeviceWindow _randomWindowOn(Random random, List<TargetPlatform> platforms) {
  final TargetPlatform platform = pickOne(random, platforms);
  final double width = randomWidth(
    random,
    least: narrowestWidth,
    most: _widestWindowWidth,
  );
  return (platform: platform, width: width);
}

Future<void> _pumpOnWindow(
  WidgetTester tester,
  _DeviceWindow window,
  Widget child,
) async {
  await pumpScrollableOnPlatform(
    tester,
    width: window.width,
    platform: window.platform,
    child: child,
  );
}

Future<double> _pumpButtonHeight(
  WidgetTester tester,
  _DeviceWindow window,
) async {
  final Widget button = Align(
    alignment: Alignment.topLeft,
    child: AppButton.primary(label: _sampleText, onPressed: () {}),
  );
  await _pumpOnWindow(tester, window, button);
  return tester.getSize(find.byType(AppButton)).height;
}

Future<double> _pumpFieldHeight(
  WidgetTester tester,
  _DeviceWindow window,
) async {
  const Widget field = TextField(
    decoration: InputDecoration(hintText: _sampleText),
  );
  await _pumpOnWindow(tester, window, field);
  return tester.getSize(find.byType(TextField)).height;
}

Future<double> _pumpTextLineHeight(
  WidgetTester tester,
  _DeviceWindow window,
) async {
  const Widget bodyText = Text(_sampleText, style: AppTextStyles.body);
  await _pumpOnWindow(tester, window, bodyText);
  return tester.getSize(find.text(_sampleText)).height;
}

Future<double> _pumpShownFontSize(
  WidgetTester tester,
  _DeviceWindow window,
  TextStyle style,
) async {
  await _pumpOnWindow(tester, window, Text(_sampleText, style: style));
  final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
    find.text(_sampleText),
  );
  return paragraph.textScaler.scale(style.fontSize!);
}

Future<double> _pumpIconExtent(
  WidgetTester tester,
  _DeviceWindow window,
) async {
  const Widget icon = Align(
    alignment: Alignment.topLeft,
    child: AppIcon(AppIconKind.tasks),
  );
  await _pumpOnWindow(tester, window, icon);
  return tester.getSize(find.byType(AppIcon)).height;
}

Future<LayoutDensity> _pumpDensityOf(
  WidgetTester tester,
  _DeviceWindow window,
) async {
  await _pumpOnWindow(tester, window, const Text(_sampleText));
  final BuildContext context = tester.element(find.text(_sampleText));
  return LayoutDensity.of(context);
}

void main() {
  test('test_for_platform_property_computers_dense_touch_devices_touch', () {
    for (final TargetPlatform platform in _computerPlatforms) {
      final LayoutDensity density = LayoutDensity.forPlatform(platform);
      expect(density, LayoutDensity.dense, reason: '$platform');
    }

    for (final TargetPlatform platform in _touchPlatforms) {
      final LayoutDensity density = LayoutDensity.forPlatform(platform);
      expect(density, LayoutDensity.touch, reason: '$platform');
    }
  });

  testWidgets('test_of_property_follows_the_theme_platform_not_the_width', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9400);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _DeviceWindow window = _randomWindowOn(
        random,
        TargetPlatform.values,
      );
      final LayoutDensity density = await _pumpDensityOf(tester, window);
      expect(
        density,
        LayoutDensity.forPlatform(window.platform),
        reason: '$window',
      );
    }
  });

  testWidgets('test_apply_layout_density_property_computer_buttons_are_32', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9401);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _DeviceWindow window = _randomWindowOn(random, _computerPlatforms);
      final double height = await _pumpButtonHeight(tester, window);
      expect(height, _denseControlHeight, reason: '$window');
    }
  });

  testWidgets('test_apply_layout_density_property_touch_buttons_stay_44', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9402);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _DeviceWindow window = _randomWindowOn(random, _touchPlatforms);
      final double height = await _pumpButtonHeight(tester, window);
      expect(height, _touchControlHeight, reason: '$window');
    }
  });

  testWidgets('test_apply_layout_density_property_computer_fields_are_32', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9403);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _DeviceWindow window = _randomWindowOn(random, _computerPlatforms);
      final double height = await _pumpFieldHeight(tester, window);
      expect(height, _denseControlHeight, reason: '$window');
    }
  });

  testWidgets('test_apply_layout_density_property_touch_fields_stay_44', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9404);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _DeviceWindow window = _randomWindowOn(random, _touchPlatforms);
      final double height = await _pumpFieldHeight(tester, window);
      expect(height, _touchControlHeight, reason: '$window');
    }
  });

  testWidgets('test_apply_layout_density_property_computer_text_is_denser', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9405);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _DeviceWindow window = _randomWindowOn(random, _computerPlatforms);
      final _ShownTextSize textSize = pickOne(random, _shownTextSizes);
      final double shownFontSize = await _pumpShownFontSize(
        tester,
        window,
        textSize.style,
      );
      expect(shownFontSize, textSize.dense, reason: '$window');
    }
  });

  testWidgets('test_apply_layout_density_property_computer_body_text_is_14', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9406);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _DeviceWindow window = _randomWindowOn(random, _computerPlatforms);
      final double shownHeight = await _pumpTextLineHeight(tester, window);
      const double expectedHeight = _denseBodyFontSize * AppLineHeights.body;
      expect(shownHeight, expectedHeight, reason: '$window');
    }
  });

  testWidgets('test_apply_layout_density_property_touch_text_stays_the_same', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9407);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _DeviceWindow window = _randomWindowOn(random, _touchPlatforms);
      final _ShownTextSize textSize = pickOne(random, _shownTextSizes);
      final double shownFontSize = await _pumpShownFontSize(
        tester,
        window,
        textSize.style,
      );
      expect(shownFontSize, textSize.touch, reason: '$window');
    }
  });

  testWidgets('test_apply_layout_density_property_touch_body_text_stays_16', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9408);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _DeviceWindow window = _randomWindowOn(random, _touchPlatforms);
      final double shownHeight = await _pumpTextLineHeight(tester, window);
      const double expectedHeight = _touchBodyFontSize * AppLineHeights.body;
      expect(shownHeight, expectedHeight, reason: '$window');
    }
  });

  testWidgets('test_apply_layout_density_property_computer_icons_are_16', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9409);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _DeviceWindow window = _randomWindowOn(random, _computerPlatforms);
      final double extent = await _pumpIconExtent(tester, window);
      expect(extent, _denseIconExtent, reason: '$window');
    }
  });

  testWidgets('test_apply_layout_density_property_touch_icons_stay_20', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9410);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _DeviceWindow window = _randomWindowOn(random, _touchPlatforms);
      final double extent = await _pumpIconExtent(tester, window);
      expect(extent, _touchIconExtent, reason: '$window');
    }
  });
}
