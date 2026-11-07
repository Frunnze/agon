import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/shared/deletion_prompts.dart';
import 'package:agent_orchestration/screens/shared/deletion_refusal_dialog.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/app_dialog.dart';

import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'support/deletion_review_harness.dart';

const String _openDialogLabel = 'Show the refusal';

class _RefusalOpener extends StatelessWidget {
  const _RefusalOpener({required this.prompt, required this.explanation});

  final DeletionPrompt prompt;
  final String explanation;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppButton.secondary(
        label: _openDialogLabel,
        onPressed: () => unawaited(_openRefusal(context)),
      ),
    );
  }

  Future<void> _openRefusal(BuildContext context) {
    return showAppDialog<void>(
      context: context,
      builder: (BuildContext _) =>
          DeletionRefusalDialog(prompt: prompt, explanation: explanation),
    );
  }
}

Future<void> _openRandomRefusal(
  WidgetTester tester, {
  required Random random,
  required DeletionPrompt prompt,
  required String explanation,
}) async {
  final double width = randomWidth(
    random,
    least: narrowestWidth,
    most: widestWidth,
  );
  useViewSize(tester, Size(width, desktopHeight));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    wrapInApp(
      _RefusalOpener(prompt: prompt, explanation: explanation),
      platform: platformMeantByWidth(width),
    ),
  );
  await tapAppButton(tester, _openDialogLabel);
}

void main() {
  testWidgets('test_deletion_refusal_dialog_build_property_shows_the_'
      'refusal_in_plain_words', (WidgetTester tester) async {
    final Random random = seededRandom(52901);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DeletionPrompt prompt = randomDeletionPrompt(random);
      final String explanation = 'Because ${randomText(random)}';

      await _openRandomRefusal(
        tester,
        random: random,
        prompt: prompt,
        explanation: explanation,
      );

      expect(tester.takeException(), isNull);
      expect(find.text(prompt.title), findsOneWidget);
      expect(find.text(describeRefusalTitle(prompt)), findsOneWidget);
      expect(find.text(explanation), findsOneWidget);
    }
  });

  testWidgets('test_deletion_refusal_dialog_build_property_keep_closes_it', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(52902);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DeletionPrompt prompt = randomDeletionPrompt(random);
      await _openRandomRefusal(
        tester,
        random: random,
        prompt: prompt,
        explanation: randomText(random),
      );

      await tapAppButton(tester, prompt.keepLabel);

      expect(find.byType(DeletionRefusalDialog), findsNothing);
      expect(find.text(_openDialogLabel), findsOneWidget);
    }
  });

  testWidgets('test_deletion_refusal_dialog_build_property_never_offers_'
      'deleting_again', (WidgetTester tester) async {
    final Random random = seededRandom(52903);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DeletionPrompt prompt = randomDeletionPrompt(random);
      await _openRandomRefusal(
        tester,
        random: random,
        prompt: prompt,
        explanation: randomText(random),
      );

      final List<String> offeredLabels = <String>[
        for (final AppButton button in tester.widgetList<AppButton>(
          find.descendant(
            of: find.byType(DeletionRefusalDialog),
            matching: find.byType(AppButton),
          ),
        ))
          button.label,
      ];

      expect(offeredLabels, <String>[prompt.keepLabel]);
    }
  });
}
