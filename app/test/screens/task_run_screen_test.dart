import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/screens/chat/chat_screen.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/route_line.dart';

import '../support/app_harness.dart';

void expectRunningRun() {
  expect(find.text('release #42'), findsOneWidget);
  expect(
    find.text('Ship release 2.4 · acme-app · started 4 min ago'),
    findsOneWidget,
  );
  expect(find.text('Cancel run'), findsOneWidget);
  expect(find.text('Chat with agent'), findsOneWidget);
  expect(find.text('Steps'), findsOneWidget);
  expect(find.text('plan'), findsOneWidget);
  expect(find.text('office-server · 2 min 10 s'), findsOneWidget);
  expect(find.text('mac-studio · 4 min so far'), findsOneWidget);
  expect(find.text('Any runner with gpu'), findsOneWidget);
  expect(find.text('Next'), findsOneWidget);
  expect(find.text('build-ios log'), findsOneWidget);
  expect(find.text('Direct · encrypted'), findsOneWidget);
  expect(find.byType(RouteLine), findsOneWidget);
  expect(
    find.textContaining('Cloned acme/app into /workspace'),
    findsOneWidget,
  );
  expect(find.textContaining('Compiling 214 of 388 files'), findsOneWidget);
}

void expectFailedRun() {
  expect(find.text('release #41'), findsOneWidget);
  expect(
    find.text('Ship release 2.3 · acme-app · stopped yesterday at 18:31'),
    findsOneWidget,
  );
  expect(find.text('Ask the agent'), findsOneWidget);
  expect(find.text('Retry'), findsOneWidget);
  expect(find.text('build-ios failed on mac-studio'), findsOneWidget);
  expect(
    find.text(
      'xcodebuild stopped with code 65: no "Apple Distribution" signing '
      'certificate on this runner.',
    ),
    findsOneWidget,
  );
  expect(
    find.text('This step is pinned to mac-studio, so a retry runs there too.'),
    findsOneWidget,
  );
  expect(find.text('office-server · 2 min 4 s'), findsOneWidget);
  expect(find.text('mac-studio · 3 min 12 s'), findsOneWidget);
  expect(find.text('Did not start'), findsOneWidget);
  expect(find.text('Skipped'), findsOneWidget);
  expect(find.byType(RouteLine), findsNothing);
  expect(find.textContaining('** ARCHIVE FAILED **'), findsOneWidget);
}

void main() {
  for (final Size size in <Size>[phoneSize, desktopSize]) {
    testWidgets('running run matches the gallery at ${size.width}', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        size: size,
        route: const TaskRunRoute(GalleryRunIds.release42),
        dependencies: buildGalleryDependencies(),
      );

      expectRunningRun();
    });

    testWidgets('failed run matches the gallery at ${size.width}', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        size: size,
        route: const TaskRunRoute(GalleryRunIds.release41),
        dependencies: buildGalleryDependencies(),
      );

      expectFailedRun();
    });
  }

  testWidgets('retrying opens a new run on the same worktree', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    final AppNavigation navigation = await pumpApp(
      tester,
      size: desktopSize,
      route: const TaskRunRoute(GalleryRunIds.release41),
      dependencies: dependencies,
    );

    await tester.tap(find.text('Retry'));
    await pumpFrames(tester);

    expect(find.text('release #43'), findsOneWidget);
    expect(find.text('Cancel run'), findsOneWidget);
    expect(navigation.routes.length, 1);
  });

  testWidgets('cancelling stops the run and chat opens the agent', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    await pumpApp(
      tester,
      size: desktopSize,
      route: const TaskRunRoute(GalleryRunIds.release42),
      dependencies: dependencies,
    );

    await tester.tap(find.text('Chat with agent'));
    await pumpFrames(tester);
    expect(find.byType(ChatScreen), findsOneWidget);
    await tester.tap(find.text('Deny'));
    await pumpFrames(tester);
    await tester.tap(find.text('release #42'));
    await pumpFrames(tester);

    await tester.tap(find.text('Cancel run'));
    await pumpFrames(tester);
    final Run cancelled = dependencies.taskRepository.findRun(
      GalleryRunIds.release42,
    );
    expect(cancelled.status, RunStatus.cancelled);
    expect(find.text('Retry'), findsOneWidget);
  });
}
