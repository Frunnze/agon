import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_pairing.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/data/repository/pairing_repository.dart';

import '../../support/random_inputs.dart';
import '../fakes/support/pairing_inputs.dart';
import 'support/node_backed_pairing_rig.dart';
import 'support/pairing_repository_harness.dart';

const String _typePrefix = 'test_node_backed_pairing_repository';
const String _acceptedOutcome = 'accepted';
const int _iterations = 15;
const int _neverJoins = 1000000;
const int _largestSecondsFromExpiry = 300;
const int _quietPolls = 5;
const List<WorkspaceId> _homeWorkspaces = <WorkspaceId>[WorkspaceId('home')];

enum _Shown { nothing, liveCode, liveRequest, expiredCode, expiredRequest }

typedef _Observation = ({bool isLive, bool hasRequest});

typedef _ShowingRig = ({PairingRig rig, PairingSession? session});

_Observation _observe(PairingRepository repository) {
  return (
    isLive: repository.findActiveSession() != null,
    hasRequest: repository.findPendingRequest() != null,
  );
}

FakePairingRepository _buildFake({
  required MovableClock clock,
  required PairingSession? session,
  required PairingRequest? request,
}) {
  return FakePairingRepository(
    session: session,
    request: request,
    clock: clock,
    deviceRepository: FakeDeviceRepository(
      devices: galleryDevices,
      currentDeviceId: GalleryDeviceIds.airLaptop,
      peerAddressProblem: null,
      gitlessFolderPaths: const <String>{},
    ),
    joinOutcome: galleryPairingOutcome,
    startedPairingRendezvousProblem: null,
  );
}

Duration _randomLateness(Random random) {
  return Duration(seconds: random.nextInt(_largestSecondsFromExpiry));
}

String _describeRefusal(Object error) {
  if (error is StateError) {
    return error.message;
  }
  return '$error';
}

String _reportAccepted(Object? outcome) => _acceptedOutcome;

bool _isStateError(Object error) => error is StateError;

Future<String> _describeDecision(
  PairingRepository repository,
  List<WorkspaceId> workspaces, {
  required bool isApproval,
}) {
  final Future<Object?> deciding = isApproval
      ? repository.approvePairing(workspaces)
      : repository.rejectPairing();
  final Future<String> accepted = deciding.then(_reportAccepted);
  return accepted.catchError(_describeRefusal, test: _isStateError);
}

bool _hasJoiningDevice(_Shown shown) {
  return shown == _Shown.liveRequest || shown == _Shown.expiredRequest;
}

Future<_ShowingRig> _openRigShowing(Random random, _Shown shown) async {
  final bool hasJoiningDevice = _hasJoiningDevice(shown);
  final PairingRig rig = buildPairingRig(
    pollsBeforeJoin: hasJoiningDevice ? 0 : _neverJoins,
  );
  if (shown == _Shown.nothing) {
    return (rig: rig, session: null);
  }

  final PairingSession session = await rig.repository.startPairing();
  if (hasJoiningDevice) {
    await waitUntil(() => rig.repository.findPendingRequest() != null);
  }
  if (shown == _Shown.expiredCode || shown == _Shown.expiredRequest) {
    rig.clock.moment = session.expiresAt.add(_randomLateness(random));
  }
  return (rig: rig, session: session);
}

void main() {
  test('${_typePrefix}_find_pending_request_property_shown_only_while_'
      'its_code_is_live', () async {
    final Random random = seededRandom(81111);

    for (int i = 0; i < _iterations; i += 1) {
      final PairingRig rig = buildPairingRig(pollsBeforeJoin: 0);
      await startAndWaitForRequest(rig);
      final PairingSession session = rig.repository.findActiveSession()!;
      final PairingRequest request = rig.repository.findPendingRequest()!;
      final int offsetSeconds =
          random.nextInt(2 * _largestSecondsFromExpiry) -
          _largestSecondsFromExpiry;

      rig.clock.moment = session.expiresAt.add(
        Duration(seconds: offsetSeconds),
      );
      final PairingRequest? shown = rig.repository.findPendingRequest();

      if (offsetSeconds < 0) {
        expect(identical(shown, request), isTrue);
      } else {
        expect(shown, isNull, reason: '$offsetSeconds s after expiry');
      }
      rig.dispose();
    }
  });

  test('${_typePrefix}_find_pending_request_property_a_read_landing_'
      'after_expiry_shows_nothing', () async {
    final Random random = seededRandom(81112);

    for (int i = 0; i < _iterations; i += 1) {
      final PairingRig rig = buildPairingRig(pollsBeforeJoin: 0);
      rig.transport.holdNextReply(pairingRequestCommand);
      final PairingSession session = await rig.repository.startPairing();
      await rig.transport.heldReplyArrival;

      rig.clock.moment = session.expiresAt.add(_randomLateness(random));
      rig.transport.releaseHeldReply();
      await waitForPolls(_quietPolls);

      expect(rig.repository.findActiveSession(), isNull);
      expect(rig.repository.findPendingRequest(), isNull);
      rig.dispose();
    }
  });

  test('${_typePrefix}_find_pending_request_property_agrees_with_the_'
      'fake_around_expiry', () async {
    final Random random = seededRandom(81113);

    for (int i = 0; i < _iterations; i += 1) {
      final PairingRig rig = buildPairingRig(pollsBeforeJoin: 0);
      await startAndWaitForRequest(rig);
      final PairingSession session = rig.repository.findActiveSession()!;
      final FakePairingRepository fake = _buildFake(
        clock: rig.clock,
        session: session,
        request: randomPairingRequest(random),
      );
      final int offsetSeconds =
          random.nextInt(2 * _largestSecondsFromExpiry) -
          _largestSecondsFromExpiry;

      rig.clock.moment = session.expiresAt.add(
        Duration(seconds: offsetSeconds),
      );
      await waitForPolls(2);

      expect(_observe(rig.repository), _observe(fake));
      expect(
        _observe(rig.repository).hasRequest,
        _observe(rig.repository).isLive,
      );
      rig.dispose();
      fake.dispose();
    }
  });

  test('${_typePrefix}_require_pending_join_property_an_expired_code_'
      'refuses_as_no_code_showing', () async {
    final Random random = seededRandom(81114);

    for (int i = 0; i < _iterations; i += 1) {
      final _Shown shown = pickOne(random, <_Shown>[
        _Shown.expiredCode,
        _Shown.expiredRequest,
      ]);
      final _ShowingRig showing = await _openRigShowing(random, shown);
      final PairingRig rig = showing.rig;
      final bool isApproval = random.nextBool();

      final String outcome = await _describeDecision(
        rig.repository,
        _homeWorkspaces,
        isApproval: isApproval,
      );

      expect(outcome, noShowingPairingCode, reason: '$shown');
      expect(rig.node.countCommands(approvePairingCommand), 0);
      expect(rig.node.countCommands(rejectPairingCommand), 0);
      rig.dispose();
    }
  });

  test('${_typePrefix}_require_pending_join_property_refuses_like_the_'
      'fake', () async {
    final Random random = seededRandom(81115);

    for (int i = 0; i < _iterations * 2; i += 1) {
      final _Shown shown = pickOne(random, _Shown.values);
      final _ShowingRig showing = await _openRigShowing(random, shown);
      final PairingRig rig = showing.rig;
      final FakePairingRepository fake = _buildFake(
        clock: rig.clock,
        session: showing.session,
        request: _hasJoiningDevice(shown)
            ? randomPairingRequest(random)
            : null,
      );
      final bool isApproval = random.nextBool();

      final String nodeOutcome = await _describeDecision(
        rig.repository,
        approverWorkspaceIds,
        isApproval: isApproval,
      );
      final String fakeOutcome = await _describeDecision(
        fake,
        approverWorkspaceIds,
        isApproval: isApproval,
      );

      expect(nodeOutcome, fakeOutcome, reason: '$shown');
      rig.dispose();
      fake.dispose();
    }
  });

  test('${_typePrefix}_require_pending_join_property_a_new_code_after_'
      'an_expiry_refusal_can_be_approved', () async {
    final Random random = seededRandom(81116);

    for (int i = 0; i < _iterations; i += 1) {
      final _ShowingRig showing = await _openRigShowing(
        random,
        _Shown.expiredRequest,
      );
      final PairingRig rig = showing.rig;
      await expectLater(
        rig.repository.approvePairing(_homeWorkspaces),
        throwsStateError,
      );

      final PairingSession fresh = await rig.repository.startPairing();
      await waitUntil(() => rig.repository.findPendingRequest() != null);
      await rig.repository.approvePairing(_homeWorkspaces);

      expect(rig.node.countCommands(approvePairingCommand), 1);
      expect(rig.node.sentCodes.last, rig.node.currentCode);
      expect(rig.node.currentDisplayCode, fresh.code);
      expect(_observe(rig.repository), (isLive: false, hasRequest: false));
      rig.dispose();
    }
  });
}
