import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../support/app_harness.dart';
import '../support/random_inputs.dart';

const RunId _watchedRunId = GalleryRunIds.release42;
const List<AppRoute> _liveRunRoutes = <AppRoute>[
  TaskRunRoute(_watchedRunId),
  ChatRoute(_watchedRunId),
];

void main() {
  testWidgets('test_live_run_watch_property_watches_only_while_visible', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10091);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final FakeTaskRepository tasks =
          dependencies.taskRepository as FakeTaskRepository;
      await tester.pumpWidget(const SizedBox.shrink());
      final AppNavigation navigation = await pumpApp(
        tester,
        size: desktopSize,
        route: const SectionRoute(AppSection.tasks),
        dependencies: dependencies,
      );
      expect(tasks.isWatchingRun(_watchedRunId), isFalse);

      navigation.openRoute(pickOne(random, _liveRunRoutes));
      await pumpFrames(tester);
      expect(tasks.isWatchingRun(_watchedRunId), isTrue);

      navigation.closeRoute();
      await pumpFrames(tester);
      expect(tasks.isWatchingRun(_watchedRunId), isFalse);
    }
  });
}
