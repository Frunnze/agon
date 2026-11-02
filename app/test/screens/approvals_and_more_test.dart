import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/screens/chat/chat_screen.dart';
import 'package:agent_orchestration/screens/skills/skills_screen.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../support/app_harness.dart';

void expectGalleryApprovals() {
  expect(find.text('2 waiting. Each one needs your passkey.'), findsOneWidget);
  expect(find.text('Push 3 commits to acme/app'), findsOneWidget);
  expect(find.text('release #42 · branch release'), findsOneWidget);
  expect(find.text('Just now'), findsOneWidget);
  expect(find.text('Sign workflow train-ranker'), findsOneWidget);
  expect(
    find.text('Adds huggingface.co to its network allowlist'),
    findsOneWidget,
  );
  expect(find.text('1 h ago'), findsOneWidget);
  expect(find.text('Review'), findsNWidgets(2));
}

void main() {
  for (final Size size in <Size>[phoneSize, desktopSize]) {
    testWidgets('approvals page matches the gallery at ${size.width}', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        size: size,
        route: const SectionRoute(AppSection.approvals),
        dependencies: buildGalleryDependencies(),
      );

      expectGalleryApprovals();
      expect(
        find.text('Asked'),
        size == desktopSize ? findsOne : findsNothing,
      );
    });

    testWidgets('more page matches the gallery at ${size.width}', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        size: size,
        route: const SectionRoute(AppSection.more),
        dependencies: buildGalleryDependencies(),
      );

      for (final String text in <String>[
        'Workflows',
        'Reusable chains of agents',
        'Instructions agents can follow',
        'What every agent must follow',
        'App server, runners, audit log',
        'Your devices',
        'Pair and revoke devices',
        'Switch workspace',
        'Now in acme',
      ]) {
        expect(find.text(text), findsWidgets);
      }
    });
  }

  testWidgets('reviewing a push opens the agent chat', (
    WidgetTester tester,
  ) async {
    final AppNavigation navigation = await pumpApp(
      tester,
      size: phoneSize,
      route: const SectionRoute(AppSection.approvals),
      dependencies: buildGalleryDependencies(),
    );

    await tester.tap(find.text('Push 3 commits to acme/app'));
    await pumpFrames(tester);

    expect(navigation.currentRoute, isA<ChatRoute>());
    expect(find.byType(ChatScreen), findsOneWidget);
  });

  testWidgets('more rows open their sections', (WidgetTester tester) async {
    final AppNavigation navigation = await pumpApp(
      tester,
      size: phoneSize,
      route: const SectionRoute(AppSection.more),
      dependencies: buildGalleryDependencies(),
    );

    await tester.tap(find.text('Instructions agents can follow'));
    await pumpFrames(tester);

    expect(navigation.currentRoute, const SectionRoute(AppSection.skills));
    expect(find.byType(SkillsScreen), findsOneWidget);
  });
}
