import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_pairing.dart';
import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/data/repository/pairing_repository.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../../support/app_harness.dart';
import '../support/planned_refusal.dart';
import '../support/refused_action_properties.dart';
import '../support/refusing_place_repositories.dart';

const String _approveLabel = 'Approve';
const String _rejectLabel = 'Reject';
const String _cancelLabel = 'Cancel';
const String _showNewCodeLabel = 'Show a new code';
const SectionRoute _devicesRoute = SectionRoute(AppSection.devices);

final class _PairingPage {
  late PairingRepository pairingRepository;
  late AppNavigation navigation;

  Future<void> open(
    WidgetTester tester, {
    required Size size,
    required PlannedRefusal refusal,
    required AppRoute route,
    required PairingSession? session,
  }) async {
    final AppDependencies gallery = buildGalleryDependencies();
    pairingRepository = RefusingPairingRepository(
      stored: FakePairingRepository(
        session: session,
        request: galleryPairingRequest,
        clock: gallery.clock,
        deviceRepository: gallery.deviceRepository as FakeDeviceRepository,
        joinOutcome: galleryPairingOutcome,
        startedPairingRendezvousProblem: null,
      ),
      refusal: refusal,
    );
    navigation = await pumpApp(
      tester,
      size: size,
      route: _devicesRoute,
      dependencies: replaceRepositories(
        gallery,
        pairingRepository: pairingRepository,
      ),
    );
    navigation.openRoute(route);
    await pumpFrames(tester);
  }
}

RefusedActionCase _buildDecisionCase({
  required String functionName,
  required String actionLabel,
}) {
  final _PairingPage page = _PairingPage();

  return RefusedActionCase(
    functionName: functionName,
    actionLabel: actionLabel,
    place: RefusalPlace.dialogOverPage,
    openPage: (tester, {required size, required refusal}) => page.open(
      tester,
      size: size,
      refusal: refusal,
      route: const PairingApprovalRoute(),
      session: galleryPairingSession,
    ),
    performAction: (tester) async {
      await tapButtonLabelled(tester, actionLabel);
    },
    expectSucceeded: (tester) {
      expect(page.pairingRepository.findPendingRequest(), isNull);
      expect(page.navigation.routes.last, isNot(const PairingApprovalRoute()));
    },
  );
}

RefusedActionCase _buildCancelPairingCase() {
  final _PairingPage page = _PairingPage();

  return RefusedActionCase(
    functionName: 'cancel_pairing',
    actionLabel: _cancelLabel,
    place: RefusalPlace.dialogOverPage,
    openPage: (tester, {required size, required refusal}) => page.open(
      tester,
      size: size,
      refusal: refusal,
      route: const PairingCodeRoute(),
      session: galleryPairingSession,
    ),
    performAction: (tester) async {
      await tapButtonLabelled(tester, _cancelLabel);
    },
    expectSucceeded: (tester) {
      expect(page.pairingRepository.findActiveSession(), isNull);
      expect(
        page.navigation.routes,
        isNot(contains(const PairingCodeRoute())),
      );
    },
  );
}

RefusedActionCase _buildShowNewCodeCase() {
  final _PairingPage page = _PairingPage();

  return RefusedActionCase(
    functionName: 'show_new_code',
    actionLabel: _showNewCodeLabel,
    place: RefusalPlace.dialogOverPage,
    openPage: (tester, {required size, required refusal}) => page.open(
      tester,
      size: size,
      refusal: refusal,
      route: const PairingCodeRoute(),
      session: null,
    ),
    performAction: (tester) async {
      await tapButtonLabelled(tester, _showNewCodeLabel);
    },
    expectSucceeded: (tester) {
      expect(page.pairingRepository.findActiveSession(), isNotNull);
      expect(find.text(_showNewCodeLabel), findsNothing);
    },
  );
}

void main() {
  registerRefusedActionProperties(
    _buildDecisionCase(functionName: 'approve', actionLabel: _approveLabel),
    seed: 91201,
  );
  registerRefusedActionProperties(
    _buildDecisionCase(functionName: 'reject', actionLabel: _rejectLabel),
    seed: 91211,
  );
  registerRefusedActionProperties(_buildCancelPairingCase(), seed: 91221);
  registerRefusedActionProperties(_buildShowNewCodeCase(), seed: 91231);
}
