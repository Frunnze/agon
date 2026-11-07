import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_pairing.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/presentation/agent_place_text.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../../support/app_harness.dart';
import '../../support/server_group_repositories.dart';
import '../support/planned_refusal.dart';
import '../support/refused_action_properties.dart';
import '../support/refusing_place_repositories.dart';
import '../support/refusing_work_repositories.dart';

const SectionRoute _devicesRoute = SectionRoute(AppSection.devices);

typedef _RefusingDependencies = AppDependencies Function(
  AppDependencies base,
  PlannedRefusal refusal,
);

final class _DevicesPage {
  late AppDependencies dependencies;
  late AppNavigation navigation;

  Future<void> open(
    WidgetTester tester, {
    required Size size,
    required PlannedRefusal refusal,
    required AppDependencies base,
    required _RefusingDependencies buildRefusing,
  }) async {
    dependencies = buildRefusing(base, refusal);
    navigation = await pumpApp(
      tester,
      size: size,
      route: _devicesRoute,
      dependencies: dependencies,
    );
  }

  Future<void> takeOutOfAcme(DeviceId deviceId) async {
    final RefusingDeviceRepository devices =
        dependencies.deviceRepository as RefusingDeviceRepository;
    await devices.stored.removeDeviceFromWorkspace(
      deviceId,
      GalleryWorkspaceIds.acme,
    );
  }

  List<Device> listAcmeMembers() {
    return <Device>[
      for (final Device device in dependencies.deviceRepository.listDevices())
        if (device.workspaces.contains(GalleryWorkspaceIds.acme)) device,
    ];
  }
}

AppDependencies _refuseDeviceChanges(
  AppDependencies base,
  PlannedRefusal refusal,
) {
  return replaceRepositories(
    base,
    deviceRepository: RefusingDeviceRepository(
      stored: base.deviceRepository,
      refusal: refusal,
    ),
  );
}

RefusedActionCase _buildDeviceCase({
  required String functionName,
  required String actionLabel,
  required AppDependencies Function() buildBase,
  required _RefusingDependencies buildRefusing,
  required PerformPersonAction Function(_DevicesPage page) buildAction,
  required void Function(_DevicesPage page) expectSucceeded,
}) {
  final _DevicesPage page = _DevicesPage();

  return RefusedActionCase(
    functionName: functionName,
    actionLabel: actionLabel,
    place: RefusalPlace.dialogOverPage,
    openPage: (tester, {required size, required refusal}) => page.open(
      tester,
      size: size,
      refusal: refusal,
      base: buildBase(),
      buildRefusing: buildRefusing,
    ),
    performAction: buildAction(page),
    expectSucceeded: (tester) => expectSucceeded(page),
  );
}

List<RefusedActionCase> _buildDeviceCases() {
  late int membersBeforeAction;

  return <RefusedActionCase>[
    _buildDeviceCase(
      functionName: 'add_device',
      actionLabel: 'Add a device',
      buildBase: buildGalleryDependencies,
      buildRefusing: _refuseDeviceChanges,
      buildAction: (page) => (tester) async {
        await page.takeOutOfAcme(GalleryDeviceIds.macStudio);
        await pumpFrames(tester);
        membersBeforeAction = page.listAcmeMembers().length;
        await tapButtonLabelled(tester, 'Add a device');
        await tapButtonLabelled(tester, 'Add');
      },
      expectSucceeded: (page) {
        expect(page.listAcmeMembers().length, membersBeforeAction + 1);
      },
    ),
    _buildDeviceCase(
      functionName: 'remove_device',
      actionLabel: 'Remove',
      buildBase: buildGalleryDependencies,
      buildRefusing: _refuseDeviceChanges,
      buildAction: (page) => (tester) async {
        membersBeforeAction = page.listAcmeMembers().length;
        await tapButtonLabelled(tester, 'Remove');
      },
      expectSucceeded: (page) {
        expect(page.listAcmeMembers().length, membersBeforeAction - 1);
      },
    ),
    _buildDeviceCase(
      functionName: 'review_revoke',
      actionLabel: 'Revoke',
      buildBase: buildGalleryDependencies,
      buildRefusing: _refuseDeviceChanges,
      buildAction: (page) => (tester) async {
        await tapButtonLabelled(tester, 'Revoke');
        await tapButtonLabelled(tester, 'Revoke device');
      },
      expectSucceeded: (page) {
        final List<Device> devices = page.dependencies.deviceRepository
            .listDevices();
        expect(devices.where((Device device) => device.revoked), isNotEmpty);
      },
    ),
    _buildDeviceCase(
      functionName: 'pair_device',
      actionLabel: 'Pair a device',
      buildBase: _buildBaseWithoutPairing,
      buildRefusing: _refusePairing,
      buildAction: (page) =>
          (tester) => tapButtonLabelled(tester, 'Pair a device'),
      expectSucceeded: (page) {
        expect(page.navigation.routes.last, const PairingCodeRoute());
      },
    ),
    _buildDeviceCase(
      functionName: 'run_agents_locally',
      actionLabel: runLocallyLabel,
      buildBase: _buildBaseWithDockerProblem,
      buildRefusing: _refuseRunnerOffers,
      buildAction: (page) =>
          (tester) => tapButtonLabelled(tester, runLocallyLabel),
      expectSucceeded: (page) {
        final List<PlaceOffer> offers = page.dependencies.runnerRepository
            .findThisDeviceOffers()!;
        final Set<AgentPlace> places = <AgentPlace>{
          for (final PlaceOffer offer in offers) offer.place,
        };
        expect(places, contains(AgentPlace.localProcess));
      },
    ),
    _buildDeviceCase(
      functionName: 'retry_app_server',
      actionLabel: 'Try now',
      buildBase: buildDependenciesWithServerDown,
      buildRefusing: _refuseServerRetry,
      buildAction: (page) =>
          (tester) => tapButtonLabelled(tester, 'Try now'),
      expectSucceeded: (page) {
        final AppServerStatus status = page.dependencies.workspaceRepository
            .findAppServerStatus();
        expect(status.state, AppServerState.online);
      },
    ),
  ];
}

AppDependencies _buildBaseWithoutPairing() {
  final AppDependencies gallery = buildGalleryDependencies();
  return replaceRepositories(
    gallery,
    pairingRepository: FakePairingRepository(
      session: null,
      request: null,
      clock: gallery.clock,
      deviceRepository: gallery.deviceRepository as FakeDeviceRepository,
      joinOutcome: galleryPairingOutcome,
      startedPairingRendezvousProblem: null,
    ),
  );
}

AppDependencies _refusePairing(AppDependencies base, PlannedRefusal refusal) {
  return replaceRepositories(
    base,
    pairingRepository: RefusingPairingRepository(
      stored: base.pairingRepository,
      refusal: refusal,
    ),
  );
}

AppDependencies _buildBaseWithDockerProblem() {
  return replaceRepositories(
    buildGalleryDependencies(),
    runnerRepository: FakeRunnerRepository(
      runners: const <Runner>[],
      thisDeviceOffers: const <PlaceOffer>[
        PlaceOffer(place: AgentPlace.container, problem: 'Docker stopped'),
      ],
      thisRunnerProblem: 'Docker stopped',
    ),
  );
}

AppDependencies _refuseRunnerOffers(
  AppDependencies base,
  PlannedRefusal refusal,
) {
  return replaceRepositories(
    base,
    runnerRepository: RefusingRunnerRepository(
      stored: base.runnerRepository,
      refusal: refusal,
    ),
  );
}

AppDependencies _refuseServerRetry(
  AppDependencies base,
  PlannedRefusal refusal,
) {
  return replaceRepositories(
    base,
    workspaceRepository: RefusingWorkspaceRepository(
      stored: base.workspaceRepository,
      refusal: refusal,
    ),
  );
}

void main() {
  int seed = 92301;
  for (final RefusedActionCase actionCase in _buildDeviceCases()) {
    registerRefusedActionProperties(actionCase, seed: seed);
    seed += 10;
  }
}
