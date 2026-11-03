import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/blinking_cursor.dart';
import 'package:agent_orchestration/widgets/count_badge.dart';
import 'package:agent_orchestration/widgets/label_chip.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/notice_banner.dart';
import 'package:agent_orchestration/widgets/slots_indicator.dart';
import 'package:agent_orchestration/widgets/status_label.dart';

import '../support/random_inputs.dart';
import '../support/widget_harness.dart';

Widget buildRandomIndicators(Random random) {
  final int total = random.nextInt(6);
  final String phrase = randomWordPhrase(random);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      AppButton.primary(
        label: 'Start ${randomText(random)}',
        onPressed: () {},
        icon: AppIconKind.play,
      ),
      AppButton.secondary(label: phrase, onPressed: null),
      AppButton.danger(label: 'Revoke device', onPressed: () {}),
      StatusLabel(
        text: randomText(random),
        tone: pickOne(random, StatusTone.values),
        icon: pickOne(random, AppIconKind.values),
      ),
      ChipList(<String>[for (int i = 0; i < total; i += 1) 'label-$i']),
      CountBadge(1 + random.nextInt(120)),
      SlotsIndicator(total: total, busy: random.nextInt(total + 1)),
      NoticeBanner(
        tone: pickOne(random, BannerTone.values),
        icon: AppIconKind.alert,
        title: randomText(random),
        body: <Widget>[Text(randomText(random))],
        actions: <Widget>[AppButton.secondary(label: 'Try', onPressed: () {})],
      ),
      MixedText(<TextSegment>[
        TextSegment(randomText(random)),
        TextSegment.monospace(randomText(random)),
      ]),
      const BlinkingCursor(),
    ],
  );
}

void main() {
  testWidgets('test_indicators_property_render_at_any_width', (
    WidgetTester tester,
  ) async {
    await expectRendersAtRandomWidths(
      tester,
      seed: 2001,
      buildChild: buildRandomIndicators,
    );
  });

  testWidgets('test_app_button_property_taps_reach_the_callback', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(2002);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      int tapCount = 0;
      final String label = 'Button ${random.nextInt(1000)}';
      await pumpScrollableAtWidth(
        tester,
        width: randomWidth(random, least: 320, most: 1600),
        child: AppButton.primary(label: label, onPressed: () => tapCount += 1),
      );
      await tester.tap(find.text(label));
      expect(tapCount, 1);
    }
  });

  test('test_count_badge_property_rejects_counts_below_one', () {
    final Random random = seededRandom(2003);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int count = random.nextInt(200) - 100;
      if (count < 1) {
        expect(() => CountBadge(count), throwsArgumentError);
      } else {
        expect(CountBadge(count).count, count);
      }
    }
  });

  test('test_slots_indicator_property_busy_within_total', () {
    final Random random = seededRandom(2004);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int total = random.nextInt(8) - 1;
      final int busy = random.nextInt(10) - 1;
      final bool isValid = total >= 0 && busy >= 0 && busy <= total;
      if (isValid) {
        expect(SlotsIndicator(total: total, busy: busy).busy, busy);
      } else {
        expect(
          () => SlotsIndicator(total: total, busy: busy),
          throwsArgumentError,
        );
      }
    }
  });

  test('test_hover_fill_property_differs_from_resting_fill', () {
    for (final ButtonTone tone in ButtonTone.values) {
      expect(tone.hoverFill, isNot(tone.fill));
    }
  });
}
