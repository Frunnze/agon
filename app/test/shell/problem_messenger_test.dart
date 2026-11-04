import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/shell/problem_messenger.dart';

import '../support/random_inputs.dart';

const String _describedProblem = 'could not reach the app server';

Widget _buildWindows(List<GlobalKey<ScaffoldMessengerState>> messengerKeys) {
  return Row(
    textDirection: TextDirection.ltr,
    children: <Widget>[
      for (final GlobalKey<ScaffoldMessengerState> messengerKey
          in messengerKeys)
        Expanded(
          child: MaterialApp(
            scaffoldMessengerKey: messengerKey,
            home: const Scaffold(body: SizedBox.expand()),
          ),
        ),
    ],
  );
}

void main() {
  testWidgets('test_show_problem_property_every_open_window_shows_it', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9101);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ProblemMessenger messenger = ProblemMessenger();
      final int windowCount = 1 + random.nextInt(3);
      final List<GlobalKey<ScaffoldMessengerState>> keys =
          <GlobalKey<ScaffoldMessengerState>>[
            for (int window = 0; window < windowCount; window += 1)
              messenger.addMessengerKey(),
          ];
      final GlobalKey<ScaffoldMessengerState> removed =
          keys[random.nextInt(windowCount)];
      final bool removesOne = windowCount > 1 && random.nextBool();
      if (removesOne) {
        messenger.removeMessengerKey(removed);
      }
      await tester.pumpWidget(_buildWindows(keys));

      final bool isShown = messenger.showProblem(
        StateError(_describedProblem),
        StackTrace.current,
      );
      await tester.pump();

      expect(isShown, isTrue);
      final int expectedCount = removesOne ? windowCount - 1 : windowCount;
      expect(find.text(_describedProblem), findsNWidgets(expectedCount));
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  test('test_show_problem_property_unmounted_messenger_declines', () {
    final Random random = seededRandom(9995);
    final ProblemMessenger messenger = ProblemMessenger();
    messenger.addMessengerKey();
    for (int i = 0; i < propertyIterations; i += 1) {
      final Object problem = StateError(randomText(random));
      expect(messenger.showProblem(problem, StackTrace.current), isFalse);
    }
  });

  testWidgets('test_show_problem_property_refusal_text_is_shown', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9996);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ProblemMessenger messenger = ProblemMessenger();
      await tester.pumpWidget(
        _buildWindows(<GlobalKey<ScaffoldMessengerState>>[
          messenger.addMessengerKey(),
        ]),
      );
      final StateError problem = StateError(
        'Locked ${randomWordPhrase(random)} $i',
      );

      expect(messenger.showProblem(problem, StackTrace.current), isTrue);
      await tester.pump();

      expect(find.text(problem.message), findsOneWidget);
      expect(
        messenger.showProblem(RangeError('bug'), StackTrace.current),
        isFalse,
      );
    }
  });

  testWidgets('test_show_problem_property_unknown_problems_are_not_shown', (
    WidgetTester tester,
  ) async {
    final ProblemMessenger messenger = ProblemMessenger();
    final GlobalKey<ScaffoldMessengerState> key = messenger.addMessengerKey();
    await tester.pumpWidget(_buildWindows(<GlobalKey<ScaffoldMessengerState>>[
      key,
    ]));

    final bool isShown = messenger.showProblem(
      const FormatException('internal detail'),
      StackTrace.current,
    );

    expect(isShown, isFalse);
  });
}
