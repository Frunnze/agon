import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/screens/pairing.dart';
import 'package:agent_orchestration/widgets/notice_banner.dart';

import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';

const String _longProblem =
    'a very long reason that keeps going and going so that it has to wrap '
    'across several lines on a narrow phone screen without overflowing';
const List<String> _sampleProblems = <String>[
  'no peer endpoint',
  'the relay did not answer: connection refused by relay.example.net',
  'Ünïcødé problem',
  _longProblem,
];

String _randomProblem(Random random) {
  if (random.nextBool()) {
    return pickOne(random, _sampleProblems);
  }
  return '${randomWordPhrase(random)} ${randomText(random)}';
}

Widget _buildBanner(Random random) {
  return RendezvousProblemBanner(problem: _randomProblem(random));
}

void main() {
  testWidgets('test_rendezvous_problem_banner_build_property_'
      'fits_every_width', (WidgetTester tester) async {
    await expectRendersAtRandomWidths(
      tester,
      seed: 73701,
      buildChild: _buildBanner,
    );
  });

  testWidgets('test_rendezvous_problem_banner_build_property_'
      'says_who_can_and_cannot_use_the_code_and_why', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(73702);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String problem = _randomProblem(random);
      final double width = randomWidth(
        random,
        least: narrowestWidth,
        most: widestWidth,
      );

      await pumpScrollableAtWidth(
        tester,
        width: width,
        child: RendezvousProblemBanner(problem: problem),
      );

      expect(find.text(rendezvousProblemTitle), findsOneWidget);
      expect(find.text(rendezvousSameNetworkNote), findsOneWidget);
      expect(find.text(problem), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'width $width');
    }
  });

  testWidgets('test_rendezvous_problem_banner_build_property_'
      'is_an_attention_notice', (WidgetTester tester) async {
    final Random random = seededRandom(73703);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpScrollableAtWidth(
        tester,
        width: randomWidth(random, least: narrowestWidth, most: widestWidth),
        child: _buildBanner(random),
      );

      final NoticeBanner banner = tester.widget(find.byType(NoticeBanner));

      expect(banner.tone, BannerTone.attention);
      expect(banner.icon, AppIconKind.alert);
      expect(banner.title, rendezvousProblemTitle);
      expect(banner.actions, isEmpty);
    }
  });
}
