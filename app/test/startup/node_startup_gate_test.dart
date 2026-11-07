import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/app.dart';
import 'package:agent_orchestration/bridge/node/node_command_failure.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/startup/node_app_start.dart';
import 'package:agent_orchestration/startup/node_startup.dart';
import 'package:agent_orchestration/startup/node_startup_gate.dart';
import 'package:agent_orchestration/startup/startup_pages.dart';

import '../support/random_inputs.dart';
import '../support/widget_harness.dart';

typedef _StartupProblem = ({
  String nodeMessage,
  String? nodeKind,
  String shownText,
});

const List<_StartupProblem> _forgottenDeviceProblems = <_StartupProblem>[
  (
    nodeMessage: 'the app server answered 401: the device is not paired',
    nodeKind: null,
    shownText: 'the device is not paired',
  ),
  (
    nodeMessage: 'the app server answered 403: the device has been revoked',
    nodeKind: null,
    shownText: 'the device has been revoked',
  ),
  (
    nodeMessage: 'this device has no account yet',
    nodeKind: noAccountFailureKind,
    shownText: 'this device has no account yet',
  ),
];

const List<_StartupProblem> _otherStartupProblems = <_StartupProblem>[
  (
    nodeMessage: 'could not reach the app server',
    nodeKind: null,
    shownText: 'could not reach the app server',
  ),
  (
    nodeMessage:
        'the app server answered 401: the request signature does not verify',
    nodeKind: null,
    shownText: 'the request signature does not verify',
  ),
  (
    nodeMessage: 'the app server answered 500: internal error',
    nodeKind: null,
    shownText: 'internal error',
  ),
  (
    nodeMessage: 'this device has no account yet',
    nodeKind: null,
    shownText: 'this device has no account yet',
  ),
];

const String _identityKeptMessage =
    'could not delete the device identity, nothing was forgotten: denied';

StartedApp _buildStartedApp(AppRoute initialRoute) {
  return StartedApp(
    dependencies: buildGalleryDependencies(),
    navigation: AppNavigation(initialRoute: initialRoute),
  );
}

Future<StartedApp> _recordStart(List<Completer<StartedApp>> starts) {
  final Completer<StartedApp> start = Completer<StartedApp>();
  starts.add(start);
  return start.future;
}

final class _ScriptedStarts {
  _ScriptedStarts({required this.failuresBeforeSuccess});

  final int failuresBeforeSuccess;
  int attempts = 0;
  final List<Completer<StartedApp>> pending = <Completer<StartedApp>>[];

  Future<StartedApp> start() {
    attempts += 1;
    return _recordStart(pending);
  }

  void finishLatest() {
    final Completer<StartedApp> latest = pending.last;
    if (attempts <= failuresBeforeSuccess) {
      latest.completeError(StateError('could not reach the app server'));
      return;
    }
    latest.complete(_buildStartedApp(const SectionRoute(AppSection.tasks)));
  }
}

final class _RecordedStarts {
  _RecordedStarts({required this.appProblem});

  final _StartupProblem appProblem;
  final List<Completer<StartedApp>> appStarts = <Completer<StartedApp>>[];
  final List<Completer<StartedApp>> newDeviceStarts =
      <Completer<StartedApp>>[];

  Future<StartedApp> startApp() => _recordStart(appStarts);

  Future<StartedApp> startAppAsNewDevice() => _recordStart(newDeviceStarts);

  void failLatestAppStart() {
    appStarts.last.completeError(
      translateNodeFailure(
        NodeCommandFailure(appProblem.nodeMessage, kind: appProblem.nodeKind),
      ),
    );
  }
}

Widget _buildStartedAppWidget(StartedApp started) {
  return AgentOrchestrationApp(
    dependencies: started.dependencies,
    navigation: started.navigation,
    messengerKey: GlobalKey<ScaffoldMessengerState>(),
    runWindowOpener: null,
  );
}

Widget _buildGate({
  required Key key,
  required AppStart startApp,
  required AppStart startAppAsNewDevice,
}) {
  final NodeStartup startup = NodeStartup(
    startApp: startApp,
    startAppAsNewDevice: startAppAsNewDevice,
  );
  startup.start();
  return NodeStartupGate(
    key: key,
    startup: startup,
    buildStartedApp: _buildStartedAppWidget,
  );
}

Future<void> _pumpFailedGate(
  WidgetTester tester, {
  required int iteration,
  required _RecordedStarts starts,
}) async {
  await tester.pumpWidget(
    _buildGate(
      key: ValueKey<int>(iteration),
      startApp: starts.startApp,
      startAppAsNewDevice: starts.startAppAsNewDevice,
    ),
  );
  starts.failLatestAppStart();
  await tester.pump();
}

void main() {
  testWidgets('test_node_startup_gate_property_retries_until_started', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9997);
    useViewSize(tester, const Size(desktopWidth, desktopHeight));
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _ScriptedStarts starts = _ScriptedStarts(
        failuresBeforeSuccess: random.nextInt(3),
      );
      await tester.pumpWidget(
        _buildGate(
          key: ValueKey<int>(i),
          startApp: starts.start,
          startAppAsNewDevice: starts.start,
        ),
      );
      expect(find.byType(StartupWaitingPage), findsOneWidget);

      for (
        int failure = 0;
        failure < starts.failuresBeforeSuccess;
        failure += 1
      ) {
        starts.finishLatest();
        await tester.pump();
        expect(find.text('could not reach the app server'), findsOneWidget);
        await tester.tap(find.text(retryStartupLabel));
        await tester.pump();
      }
      starts.finishLatest();
      await tester.pump();
      await tester.pump();

      expect(find.byType(AgentOrchestrationApp), findsOneWidget);
      expect(starts.attempts, starts.failuresBeforeSuccess + 1);
    }
  });

  testWidgets(
    'test_node_startup_gate_property_set_up_offered_when_forgotten',
    (WidgetTester tester) async {
      final Random random = seededRandom(9998);
      useViewSize(tester, const Size(desktopWidth, desktopHeight));
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final bool isForgotten = random.nextBool();
        final List<_StartupProblem> problems = isForgotten
            ? _forgottenDeviceProblems
            : _otherStartupProblems;
        final _StartupProblem problem = pickOne(random, problems);
        final _RecordedStarts starts = _RecordedStarts(appProblem: problem);

        await _pumpFailedGate(tester, iteration: i, starts: starts);

        expect(find.text(problem.shownText), findsOneWidget);
        expect(find.textContaining('answered'), findsNothing);
        expect(find.text(retryStartupLabel), findsOneWidget);
        expect(
          find.text(setUpDeviceAgainLabel),
          isForgotten ? findsOneWidget : findsNothing,
        );
        expect(starts.newDeviceStarts, isEmpty);
      }
    },
  );

  testWidgets('test_node_startup_gate_property_set_up_starts_a_new_device', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9999);
    useViewSize(tester, const Size(desktopWidth, desktopHeight));
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final int retries = random.nextInt(3);
      final _RecordedStarts starts = _RecordedStarts(
        appProblem: pickOne(random, _forgottenDeviceProblems),
      );
      await _pumpFailedGate(tester, iteration: i, starts: starts);
      for (int retry = 0; retry < retries; retry += 1) {
        await tester.tap(find.text(retryStartupLabel));
        await tester.pump();
        starts.failLatestAppStart();
        await tester.pump();
      }

      await tester.tap(find.text(setUpDeviceAgainLabel));
      await tester.pump();
      expect(find.byType(StartupWaitingPage), findsOneWidget);
      starts.newDeviceStarts.last.complete(
        _buildStartedApp(const SetupRoleRoute()),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AgentOrchestrationApp), findsOneWidget);
      expect(starts.appStarts.length, retries + 1);
      expect(starts.newDeviceStarts.length, 1);
    }
  });

  testWidgets('a failed forgetting shows its problem with only try again', (
    WidgetTester tester,
  ) async {
    useViewSize(tester, const Size(desktopWidth, desktopHeight));
    final _RecordedStarts starts = _RecordedStarts(
      appProblem: _forgottenDeviceProblems.first,
    );
    await _pumpFailedGate(tester, iteration: 0, starts: starts);

    await tester.tap(find.text(setUpDeviceAgainLabel));
    await tester.pump();
    starts.newDeviceStarts.last.completeError(
      StateError(_identityKeptMessage),
    );
    await tester.pump();

    expect(find.text(_identityKeptMessage), findsOneWidget);
    expect(find.text(retryStartupLabel), findsOneWidget);
    expect(find.text(setUpDeviceAgainLabel), findsNothing);
    expect(starts.newDeviceStarts.length, 1);
  });
}
