import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/icons/app_icon.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/icons/app_icon_painter.dart';
import 'package:agent_orchestration/icons/icon_path_parser.dart';
import 'package:agent_orchestration/icons/icon_shape.dart';
import 'package:agent_orchestration/icons/spinning_box.dart';

import '../support/random_inputs.dart';
import '../support/widget_harness.dart';

String randomPathData(Random random) {
  final StringBuffer buffer = StringBuffer('M${random.nextInt(24)} 4');
  for (int i = 0; i < random.nextInt(6); i += 1) {
    final int x = random.nextInt(24);
    final int y = random.nextInt(24);
    buffer.write(
      pickOne(random, <String>[
        'L$x $y',
        'l-$x.5 $y',
        'h$x',
        'V$y',
        'c1 2 3 4 $x $y',
        'a2 2 0 0 1 $x-$y',
        'z',
      ]),
    );
  }
  return buffer.toString();
}

void main() {
  test('test_parse_icon_path_property_every_gallery_icon_parses', () {
    for (final AppIconKind kind in AppIconKind.values) {
      for (final IconShape shape in kind.shapes) {
        final Rect bounds = buildIconShapePath(shape).getBounds();
        expect(bounds.left >= -1 && bounds.right <= 25, isTrue);
        expect(bounds.top >= -1 && bounds.bottom <= 25, isTrue);
      }
    }
  });

  test('test_parse_icon_path_property_generated_paths_stay_finite', () {
    final Random random = seededRandom(2601);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Rect bounds = parseIconPath(randomPathData(random)).getBounds();
      expect(bounds.isFinite, isTrue);
    }
  });

  test('test_parse_icon_path_property_garbage_fails_with_format_error', () {
    final Random random = seededRandom(2602);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String text = randomText(random);
      try {
        parseIconPath(text);
      } on FormatException {
        continue;
      }
    }
    expect(() => parseIconPath('M1'), throwsFormatException);
    expect(() => parseIconPath('12 4'), throwsFormatException);
    expect(() => parseIconPath('M1 2 Q3 4'), throwsFormatException);
  });

  test('test_tokenize_icon_path_property_tokens_rejoin_to_the_input', () {
    final Random random = seededRandom(2603);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String pathData = randomPathData(random);
      final List<String> tokens = tokenizeIconPath(pathData);
      final String squeezed = pathData.replaceAll(RegExp(r'[\s,]'), '');

      expect(tokens.join(), squeezed);
    }
  });

  test('test_build_icon_shape_path_property_circles_fit_their_radius', () {
    final Random random = seededRandom(2604);

    for (int i = 0; i < propertyIterations; i += 1) {
      final double radius = 0.5 + random.nextDouble() * 10;
      final Rect bounds = buildIconShapePath(
        IconCircleShape(
          centerHorizontal: 12,
          centerVertical: 12,
          radius: radius,
        ),
      ).getBounds();
      expect(bounds.width, closeTo(radius * 2, 0.01));
    }
  });

  testWidgets('test_app_icon_property_only_the_spinner_spins', (
    WidgetTester tester,
  ) async {
    for (final AppIconKind kind in AppIconKind.values) {
      await pumpScrollableAtWidth(
        tester,
        width: phoneWidth,
        child: AppIcon(kind, size: AppIconSize.small),
      );
      final bool spins = find.byType(SpinningBox).evaluate().isNotEmpty;
      expect(spins, kind == AppIconKind.spinner);
      expect(
        tester.getSize(find.byType(CustomPaint).last),
        const Size.square(16),
      );
    }
  });

  test('test_should_repaint_property_only_when_kind_or_color_changes', () {
    final Random random = seededRandom(2605);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppIconKind kind = pickOne(random, AppIconKind.values);
      final AppIconKind other = pickOne(random, AppIconKind.values);
      const Color color = Color(0xFFFFFFFF);
      final AppIconPainter painter = AppIconPainter(kind: kind, color: color);

      expect(
        painter.shouldRepaint(AppIconPainter(kind: other, color: color)),
        kind != other,
      );
    }
  });
}
