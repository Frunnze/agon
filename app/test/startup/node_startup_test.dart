import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/startup/node_app_start.dart';
import 'package:agent_orchestration/startup/node_startup.dart';
import 'package:agent_orchestration/startup/startup_stage.dart';

import '../support/random_inputs.dart';

final class _PendingStarts {
  final List<Completer<StartedApp>> appStarts = <Completer<StartedApp>>[];
  final List<Completer<StartedApp>> newDeviceStarts =
      <Completer<StartedApp>>[];
  final List<Completer<StartedApp>> everyStartInOrder =
      <Completer<StartedApp>>[];

  Future<StartedApp> startApp() => _record(appStarts);

  Future<StartedApp> startAppAsNewDevice() => _record(newDeviceStarts);

  Future<StartedApp> _record(List<Completer<StartedApp>> starts) {
    final Completer<StartedApp> start = Completer<StartedApp>();
    starts.add(start);
    everyStartInOrder.add(start);
    return start.future;
  }
}

StartedApp _buildStartedApp() {
  return StartedApp(
    dependencies: buildGalleryDependencies(),
    navigation: AppNavigation(
      initialRoute: const SectionRoute(AppSection.tasks),
    ),
  );
}

NodeStartup _buildStartup(_PendingStarts starts) {
  return NodeStartup(
    startApp: starts.startApp,
    startAppAsNewDevice: starts.startAppAsNewDevice,
  );
}

void main() {
  test('test_start_property_waits_until_the_node_answers', () async {
    final _PendingStarts starts = _PendingStarts();
    final NodeStartup startup = _buildStartup(starts);

    startup.start();

    expect(startup.stage, isA<StartupWaiting>());
    expect(starts.appStarts, hasLength(1));
    final StartedApp started = _buildStartedApp();
    starts.appStarts.single.complete(started);
    await pumpEventQueue();
    final StartupStage stage = startup.stage;
    expect(stage, isA<StartupFinished>());
    expect((stage as StartupFinished).started, same(started));
  });

  test('test_start_property_failure_keeps_the_problem', () async {
    final Random random = seededRandom(5201);
    for (int i = 0; i < propertyIterations; i += 1) {
      final _PendingStarts starts = _PendingStarts();
      final NodeStartup startup = _buildStartup(starts);
      final StateError problem = StateError(randomText(random));

      startup.start();
      starts.appStarts.single.completeError(problem);
      await pumpEventQueue();

      final StartupStage stage = startup.stage;
      expect(stage, isA<StartupFailed>());
      expect((stage as StartupFailed).problem, same(problem));
    }
  });

  test('test_start_property_only_the_latest_attempt_decides', () async {
    final Random random = seededRandom(5202);
    for (int i = 0; i < propertyIterations; i += 1) {
      final _PendingStarts starts = _PendingStarts();
      final NodeStartup startup = _buildStartup(starts);
      startup.start();
      final int laterAttempts = random.nextInt(4);
      for (int attempt = 0; attempt < laterAttempts; attempt += 1) {
        if (random.nextBool()) {
          startup.start();
        } else {
          startup.setUpAgain();
        }
      }
      final Completer<StartedApp> latest = starts.everyStartInOrder.last;
      final StartedApp started = _buildStartedApp();
      latest.complete(started);
      for (final Completer<StartedApp> earlier in starts.everyStartInOrder) {
        if (!earlier.isCompleted) {
          earlier.completeError(StateError('an earlier attempt'));
        }
      }
      await pumpEventQueue();

      final StartupStage stage = startup.stage;
      expect(stage, isA<StartupFinished>());
      expect((stage as StartupFinished).started, same(started));
    }
  });

  test('test_start_property_tells_listeners_of_each_stage', () async {
    final _PendingStarts starts = _PendingStarts();
    final NodeStartup startup = _buildStartup(starts);
    final List<Type> stages = <Type>[];
    startup.addListener(() => stages.add(startup.stage.runtimeType));

    startup.start();
    starts.appStarts.single.completeError(StateError('down'));
    await pumpEventQueue();
    startup.start();
    starts.appStarts.last.complete(_buildStartedApp());
    await pumpEventQueue();

    expect(stages, <Type>[
      StartupWaiting,
      StartupFailed,
      StartupWaiting,
      StartupFinished,
    ]);
  });
}
