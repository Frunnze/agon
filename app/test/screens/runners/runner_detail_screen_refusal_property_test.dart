import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_runners.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/presentation/agent_place_text.dart';
import 'package:agent_orchestration/screens/shared/action_refusal.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/app_harness.dart';
import '../../support/runner_pages.dart';
import '../../support/sample_runners.dart';
import '../support/planned_refusal.dart';
import '../support/refused_action_properties.dart';
import '../support/refusing_work_repositories.dart';

const DeviceId _otherRunnerId = GalleryDeviceIds.macStudio;
const String _pauseLabel = 'Pause new runs';
const String _resumeLabel = 'Resume new runs';

final class _RunnerPage {
  late RefusingRunnerRepository runnerRepository;

  Future<void> open(
    WidgetTester tester, {
    required Size size,
    required PlannedRefusal refusal,
    required DeviceId runnerId,
  }) async {
    final AppDependencies gallery = buildGalleryDependencies();
    runnerRepository = RefusingRunnerRepository(
      stored: buildOfferingRunners(
        runners: <Runner>[
          ...galleryRunners,
          buildOnlineRunnerOn(thisRunnerDeviceId),
        ],
        offers: const <PlaceOffer>[
          PlaceOffer(place: AgentPlace.localProcess, problem: null),
        ],
        problem: null,
      ),
      refusal: refusal,
    );
    await pumpApp(
      tester,
      size: size,
      route: RunnerDetailRoute(runnerId),
      dependencies: replaceRepositories(
        gallery,
        deviceRepository: buildRunnerDevices(peerAddressProblem: null),
        runnerRepository: runnerRepository,
      ),
    );
  }

  bool isAcceptingNewRuns() {
    return runnerRepository.findRunner(_otherRunnerId).acceptingNewRuns;
  }
}

RefusedActionCase _buildPauseCase() {
  final _RunnerPage page = _RunnerPage();

  return RefusedActionCase(
    functionName: 'pause_new_runs',
    actionLabel: _pauseLabel,
    place: RefusalPlace.dialogOverPage,
    openPage: (tester, {required size, required refusal}) => page.open(
      tester,
      size: size,
      refusal: refusal,
      runnerId: _otherRunnerId,
    ),
    performAction: (tester) => tapButtonLabelled(tester, _pauseLabel),
    expectSucceeded: (tester) {
      expect(page.isAcceptingNewRuns(), isFalse);
      expect(find.text(_resumeLabel), findsOneWidget);
    },
  );
}

RefusedActionCase _buildResumeCase() {
  final _RunnerPage page = _RunnerPage();

  return RefusedActionCase(
    functionName: 'resume_new_runs',
    actionLabel: _resumeLabel,
    place: RefusalPlace.dialogOverPage,
    openPage: (tester, {required size, required refusal}) async {
      await page.open(
        tester,
        size: size,
        refusal: refusal,
        runnerId: _otherRunnerId,
      );
      await page.runnerRepository.stored.pauseRunner(_otherRunnerId);
      await pumpFrames(tester);
    },
    performAction: (tester) => tapButtonLabelled(tester, _resumeLabel),
    expectSucceeded: (tester) {
      expect(page.isAcceptingNewRuns(), isTrue);
      expect(find.text(_pauseLabel), findsOneWidget);
    },
  );
}

RefusedActionCase _buildChooseOffersCase() {
  final _RunnerPage page = _RunnerPage();
  final String dockerTitle = describeAgentPlaceTitle(AgentPlace.container);

  return RefusedActionCase(
    functionName: 'choose_agent_offers',
    actionLabel: changeSettingLabel,
    place: RefusalPlace.dialogOverPage,
    openPage: (tester, {required size, required refusal}) => page.open(
      tester,
      size: size,
      refusal: refusal,
      runnerId: thisRunnerDeviceId,
    ),
    performAction: (tester) async {
      final Finder dockerChoice = find.text(dockerTitle);
      await tester.ensureVisible(dockerChoice);
      await tester.tap(dockerChoice);
      await pumpFrames(tester);
    },
    expectSucceeded: (tester) {
      final List<PlaceOffer> offers = page.runnerRepository
          .findThisDeviceOffers()!;
      expect(findOfferedPlaces(offers), contains(AgentPlace.container));
      expect(findTickedPlaces(tester), findOfferedPlaces(offers));
    },
  );
}

void main() {
  registerRefusedActionProperties(_buildPauseCase(), seed: 91301);
  registerRefusedActionProperties(_buildResumeCase(), seed: 91311);
  registerRefusedActionProperties(_buildChooseOffersCase(), seed: 91321);
}
