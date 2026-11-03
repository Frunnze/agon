import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/shell/problem_messenger.dart';

import '../support/random_inputs.dart';

Widget _buildMessengerHost(ProblemMessenger messenger) {
  return MaterialApp(
    scaffoldMessengerKey: messenger.messengerKey,
    home: const Scaffold(body: SizedBox.shrink()),
  );
}

void main() {
  test('test_show_problem_property_unmounted_messenger_declines', () {
    final Random random = seededRandom(9995);
    final ProblemMessenger messenger = ProblemMessenger();
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
      await tester.pumpWidget(_buildMessengerHost(messenger));
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
}
