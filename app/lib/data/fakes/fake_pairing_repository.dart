import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/data/repository/pairing_repository.dart';
import 'package:agent_orchestration/data/rules/naming.dart';
import 'package:agent_orchestration/data/rules/setup_input_rules.dart';

const Duration _pairingLifetime = Duration(minutes: 5);
const String _freshPairingCode = '9QX-3MD';
const List<int> _fakePublicKey = <int>[0];

final class FakePairingRepository extends ChangeNotifier
    implements PairingRepository {
  FakePairingRepository({
    required PairingSession? session,
    required PairingRequest? request,
    required Clock clock,
    required FakeDeviceRepository deviceRepository,
    required PairingOutcome joinOutcome,
    required String? startedPairingRendezvousProblem,
  }) : _session = session,
       _request = request,
       _clock = clock,
       _deviceRepository = deviceRepository,
       _joinOutcome = joinOutcome,
       _startedPairingRendezvousProblem = startedPairingRendezvousProblem;

  final Clock _clock;
  final FakeDeviceRepository _deviceRepository;
  final PairingOutcome _joinOutcome;
  final String? _startedPairingRendezvousProblem;
  PairingSession? _session;
  PairingRequest? _request;

  @override
  PairingSession? findActiveSession() {
    final PairingSession? session = _session;
    if (session == null || !session.expiresAt.isAfter(_clock.now())) {
      return null;
    }
    return session;
  }

  @override
  Future<PairingSession> startPairing() async {
    final DateTime now = _clock.now();
    final PairingSession session = PairingSession(
      code: _freshPairingCode,
      createdAt: now,
      expiresAt: now.add(_pairingLifetime),
      rendezvousProblem: _startedPairingRendezvousProblem,
    );

    _session = session;
    _request = null;
    notifyListeners();
    return session;
  }

  @override
  PairingRequest? findPendingRequest() {
    if (findActiveSession() == null) {
      return null;
    }
    return _request;
  }

  @override
  Future<Device> approvePairing(List<WorkspaceId> workspaces) async {
    if (workspaces.isEmpty) {
      throw ArgumentError.value(workspaces, 'workspaces', 'Choose one');
    }

    final PairingRequest request = _requirePendingRequest();
    final Device approver = _deviceRepository.currentDevice();
    final bool isApproverInEvery = workspaces.every(
      approver.workspaces.contains,
    );
    if (!isApproverInEvery) {
      throw ArgumentError.value(
        workspaces,
        'workspaces',
        'This device is not in every chosen workspace',
      );
    }

    final DateTime now = _clock.now();
    final Device device = Device(
      id: DeviceId('paired-${request.deviceName}'),
      name: request.deviceName,
      role: request.role,
      kind: DeviceKind.computer,
      keyKind: request.keyKind,
      signingPublicKey: _fakePublicKey,
      sealingPublicKey: _fakePublicKey,
      workspaces: workspaces.toSet().toList(),
      pairedAt: now,
      approvedBy: approver.id,
      lastSeen: now,
      revoked: false,
    );

    await _deviceRepository.addPairedDevice(device);
    _closeSession();
    return device;
  }

  @override
  Future<void> rejectPairing() async {
    _requirePendingRequest();
    _closeSession();
  }

  @override
  Future<void> cancelPairing() async {
    if (findActiveSession() == null) {
      throw StateError(noShowingPairingCode);
    }
    _closeSession();
  }

  @override
  WaitingJoin? findWaitingJoin() => null;

  @override
  Future<PairingOutcome> joinWithCode({
    required String? serverAddress,
    required String code,
    required String deviceName,
    required DeviceRole role,
  }) async {
    final String? problem = describeJoinInputProblem(
      serverAddress: serverAddress,
      code: code,
    );
    if (problem != null) {
      throw FormatException(problem, code);
    }
    final String? nameProblem = describeNameProblem(deviceName);
    if (nameProblem != null) {
      throw ArgumentError(nameProblem);
    }

    return PairingOutcome(
      deviceName: deviceName,
      role: role,
      workspaceNames: _joinOutcome.workspaceNames,
      runnerLabels: _joinOutcome.runnerLabels,
      approverName: _joinOutcome.approverName,
    );
  }

  @override
  Future<PairingOutcome> createHostedAccount({
    required String workspaceName,
    required String deviceName,
    required DeviceRole role,
  }) async {
    final String? problem =
        describeNameProblem(deviceName) ?? describeNameProblem(workspaceName);
    if (problem != null) {
      throw ArgumentError(problem);
    }

    return PairingOutcome(
      deviceName: deviceName,
      role: role,
      workspaceNames: <String>[workspaceName],
      runnerLabels: _joinOutcome.runnerLabels,
      approverName: null,
    );
  }

  PairingRequest _requirePendingRequest() {
    final bool hasExpiredCode = _session != null && findActiveSession() == null;
    if (hasExpiredCode) {
      throw StateError(noShowingPairingCode);
    }

    final PairingRequest? request = findPendingRequest();
    if (request == null) {
      throw StateError(noDeviceWaitingToPair);
    }
    return request;
  }

  void _closeSession() {
    _session = null;
    _request = null;
    notifyListeners();
  }
}
