import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/presentation/approval_policy_text.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../support/app_harness.dart';
import '../support/form_finders.dart';
import '../support/random_inputs.dart';

const List<String> _sectionTexts = <String>[
  'Commands and pushes',
  'Auto',
  'Runs commands and pushes without asking you.',
  'Ask me',
  'Asks you before each command and each push.',
  'Projects, tasks and steps follow this unless they choose their own.',
];

void main() {
  for (final Size size in <Size>[phoneSize, desktopSize]) {
    testWidgets(
      'general settings show the commands setting at ${size.width}',
      (WidgetTester tester) async {
        await pumpApp(
          tester,
          size: size,
          route: const SectionRoute(AppSection.settings),
          dependencies: buildGalleryDependencies(),
        );

        for (final String text in _sectionTexts) {
          expect(find.text(text), findsOneWidget, reason: text);
        }
        expect(find.text('Same as the workspace'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'test_workspace_approval_policy_section_property_tap_sets_workspace',
    (WidgetTester tester) async {
      final Random random = seededRandom(9811);
      final AppDependencies dependencies = buildGalleryDependencies();
      await pumpApp(
        tester,
        size: desktopSize,
        route: const SectionRoute(AppSection.settings),
        dependencies: dependencies,
      );

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final ApprovalPolicy chosen = pickOne(random, ApprovalPolicy.values);

        await tapVisible(
          tester,
          find.text(describeApprovalPolicyTitle(chosen)),
        );
        await pumpFrames(tester);

        expect(
          dependencies.workspaceRepository.currentWorkspace().approvalPolicy,
          chosen,
        );
      }
    },
  );
}
