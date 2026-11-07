import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/task_run/retry_refusal_dialog.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/app_dialog.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_app_server_refusals.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'support/run_page_retry_harness.dart';

const String _openDialogLabel = 'Open dialog';
const int _largestReasonRepeats = 60;
const int _largestRunNumber = 999;

String _randomRunLabel(Random random) {
  return '${randomWordPhrase(random)} #${random.nextInt(_largestRunNumber)}';
}

String _randomLongReason(Random random) {
  final int repeats = 1 + random.nextInt(_largestReasonRepeats);
  return List<String>.filled(repeats, randomRefusalReason(random)).join(' ');
}

Future<void> _pumpDialogOpener(
  WidgetTester tester, {
  required double width,
  required RetryRefusalDialog dialog,
}) async {
  useViewSize(tester, Size(width, desktopHeight));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    wrapInApp(
      Builder(
        builder: (BuildContext context) => AppButton.secondary(
          label: _openDialogLabel,
          onPressed: () => showAppDialog<void>(
            context: context,
            builder: (BuildContext _) => dialog,
          ),
        ),
      ),
      platform: platformMeantByWidth(width),
    ),
  );
  await tapAppButton(tester, _openDialogLabel);
}

double _randomWindowWidth(Random random) {
  return randomWidth(random, least: narrowestWidth, most: widestWidth);
}

void main() {
  testWidgets('test_retry_refusal_dialog_build_property_shows_label_reason_'
      'and_close', (WidgetTester tester) async {
    final Random random = seededRandom(78301);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = _randomWindowWidth(random);
      final String runLabel = _randomRunLabel(random);
      final String explanation = randomRefusalReason(random);
      await _pumpDialogOpener(
        tester,
        width: width,
        dialog: RetryRefusalDialog(
          runLabel: runLabel,
          explanation: explanation,
        ),
      );

      expect(tester.takeException(), isNull, reason: 'width $width');
      expect(find.text(runLabel), findsOneWidget);
      expect(find.text(retryRefusalTitle), findsOneWidget);
      expect(find.text(explanation), findsOneWidget);
      expect(findAppButton(closeButtonLabel), findsOneWidget);
    }
  });

  testWidgets('test_retry_refusal_dialog_build_property_close_dismisses_'
      'it', (WidgetTester tester) async {
    final Random random = seededRandom(78302);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpDialogOpener(
        tester,
        width: _randomWindowWidth(random),
        dialog: RetryRefusalDialog(
          runLabel: _randomRunLabel(random),
          explanation: randomRefusalReason(random),
        ),
      );

      await tapAppButton(tester, closeButtonLabel);

      expect(tester.takeException(), isNull);
      expect(find.byType(RetryRefusalDialog), findsNothing);
      expect(findAppButton(_openDialogLabel), findsOneWidget);
    }
  });

  testWidgets('test_retry_refusal_dialog_build_property_long_reasons_still_'
      'close', (WidgetTester tester) async {
    final Random random = seededRandom(78303);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = _randomWindowWidth(random);
      await _pumpDialogOpener(
        tester,
        width: width,
        dialog: RetryRefusalDialog(
          runLabel: _randomRunLabel(random),
          explanation: _randomLongReason(random),
        ),
      );

      expect(tester.takeException(), isNull, reason: 'width $width');
      final Rect dialogArea = tester.getRect(find.byType(AppDialog));
      expect(dialogArea.left, greaterThanOrEqualTo(0));
      expect(dialogArea.right, lessThanOrEqualTo(width));
      expect(dialogArea.bottom, lessThanOrEqualTo(desktopHeight));
      await tapAppButton(tester, closeButtonLabel);
      expect(tester.takeException(), isNull, reason: 'width $width');
      expect(find.byType(RetryRefusalDialog), findsNothing);
    }
  });

  test('test_retry_refusal_dialog_constructor_property_keeps_the_run_'
      'label', () {
    final Random random = seededRandom(78304);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String runLabel = randomHostileText(random);
      final RetryRefusalDialog dialog = RetryRefusalDialog(
        runLabel: runLabel,
        explanation: randomHostileText(random),
      );

      expect(dialog.runLabel, runLabel);
    }
  });

  test('test_retry_refusal_dialog_constructor_property_keeps_the_'
      'explanation', () {
    final Random random = seededRandom(78305);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String explanation = randomHostileText(random);
      final RetryRefusalDialog dialog = RetryRefusalDialog(
        runLabel: randomHostileText(random),
        explanation: explanation,
      );

      expect(dialog.explanation, explanation);
    }
  });

  test('test_retry_refusal_dialog_constructor_property_fields_never_'
      'swap', () {
    final Random random = seededRandom(78306);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String runLabel = 'label ${randomText(random)}';
      final String explanation = 'reason ${randomText(random)}';
      final RetryRefusalDialog dialog = RetryRefusalDialog(
        runLabel: runLabel,
        explanation: explanation,
      );

      expect(dialog.runLabel, isNot(explanation));
      expect(dialog.explanation, isNot(runLabel));
    }
  });
}
