import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_runners.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/presentation/agent_login_text.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../support/app_harness.dart';
import '../support/form_finders.dart';
import '../support/random_inputs.dart';
import '../support/sample_runners.dart';
import '../support/scripted_item_draft_repository.dart';
import 'new_items/new_item_harness.dart';

const DeviceId _thisDeviceId = GalleryDeviceIds.airLaptop;
const DeviceId _otherRunnerId = GalleryDeviceIds.macStudio;
const String _otherRunnerName = 'mac-studio';
const String _loginFailure =
    'the drafting run did not finish: Not logged in · Please run /login';

Future<AppNavigation> _failDraftOn(
  WidgetTester tester, {
  required DeviceId drafter,
  required String problem,
}) async {
  final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
  final AppNavigation navigation = await openNewItem(
    tester,
    route: newItemRoutes[DraftKind.task]!,
    dependencies: replaceRepositories(
      buildNewItemDependencies(drafts),
      runnerRepository: FakeRunnerRepository(
        runners: <Runner>[
          ...galleryRunners,
          buildOnlineRunnerOn(_thisDeviceId),
        ],
        thisDeviceOffers: const <PlaceOffer>[
          PlaceOffer(place: AgentPlace.container, problem: null),
        ],
        thisRunnerProblem: null,
      ),
    ),
  );
  await startNewItemDraft(tester, 'Draft task');
  drafts.reportProgress(
    DraftRunning(drafterKind: AgentKind.claudeCode, drafterDeviceId: drafter),
  );
  await pumpFrames(tester);
  drafts.failLatestDraft(StateError(problem));
  await pumpFrames(tester);
  return navigation;
}

void main() {
  testWidgets('test_failed_draft_property_login_failures_point_to_runner', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9701);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final bool isThisDevice = random.nextBool();

      await _failDraftOn(
        tester,
        drafter: isThisDevice ? _thisDeviceId : _otherRunnerId,
        problem: _loginFailure,
      );

      final String hint = isThisDevice
          ? thisComputerLoginHint
          : describeOtherRunnerLoginHint(_otherRunnerName);
      expect(find.text(hint), findsOneWidget);
      expect(
        find.text(connectClaudeCodeLabel),
        isThisDevice ? findsOneWidget : findsNothing,
      );
    }
  });

  testWidgets('test_failed_draft_property_other_failures_point_nowhere', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9702);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _failDraftOn(
        tester,
        drafter: _thisDeviceId,
        problem: 'the agent broke ${randomWordPhrase(random)}',
      );

      expect(find.text(thisComputerLoginHint), findsNothing);
      expect(find.text(connectClaudeCodeLabel), findsNothing);
    }
  });

  testWidgets('test_failed_draft_property_connect_opens_this_runner', (
    WidgetTester tester,
  ) async {
    final AppNavigation navigation = await _failDraftOn(
      tester,
      drafter: _thisDeviceId,
      problem: _loginFailure,
    );

    await tapVisible(tester, find.text(connectClaudeCodeLabel));
    await pumpFrames(tester);

    final AppRoute shown = navigation.currentRoute;
    expect(shown, isA<RunnerDetailRoute>());
    expect((shown as RunnerDetailRoute).deviceId, _thisDeviceId);
  });
}
