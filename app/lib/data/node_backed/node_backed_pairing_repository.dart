import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/bridge/codecs/account_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/catalog_views.dart' as node;
import 'package:agent_orchestration/bridge/codecs/pairing_values.dart' as node;
import 'package:agent_orchestration/bridge/commands/account_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/commands/device_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/commands/pairing_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/pairing_repository.dart';
import 'package:agent_orchestration/data/rules/naming.dart';
import 'package:agent_orchestration/data/rules/setup_input_rules.dart';

typedef _PendingJoin = ({String code, node.JoiningDevice joining});

final class NodeBackedPairingRepository extends ChangeNotifier
    implements PairingRepository {
  NodeBackedPairingRepository({
    required NodeCommandChannel channel,
    required Clock clock,
    required Duration pollInterval,
    required List<String> runnerLabels,
  }) : _channel = channel,
       _clock = clock,
       _pollInterval = pollInterval,
       _runnerLabels = List<String>.unmodifiable(runnerLabels);

  final NodeCommandChannel _channel;
  final Clock _clock;
  final Duration _pollInterval;
  final List<String> _runnerLabels;
  PairingSession? _session;
  String? _sessionCode;
  node.JoiningDevice? _joining;
  PairingRequest? _request;
  Timer? _countdown;
  bool _isReadingRequest = false;
  WaitingJoin? _waitingJoin;

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
    final node.PairingRequestScreen screen = await executeNodeCommand(
      _channel,
      const node.StartPairingCommand(),
    );
    final PairingSession session = mapPairingSessionFromNode(screen);

    _countdown?.cancel();
    _session = session;
    _sessionCode = screen.code;
    _joining = null;
    _request = null;
    _countdown = Timer.periodic(_pollInterval, _tickCountdown);
    notifyListeners();
    return session;
  }

  @override
  PairingRequest? findPendingRequest() => _request;

  @override
  Future<Device> approvePairing(List<WorkspaceId> workspaces) async {
    if (workspaces.isEmpty) {
      throw ArgumentError.value(workspaces, 'workspaces', 'Choose one');
    }

    final _PendingJoin pending = _requirePendingJoin();
    await executeNodeCommand(
      _channel,
      node.ApprovePairingCommand(code: pending.code, workspaceIds: workspaces),
    );
    final List<node.DeviceView> devices = await executeNodeCommand(
      _channel,
      const node.ListDevicesCommand(),
    );
    final Device device = findJoinedDevice(devices, pending.joining);

    _closeSession();
    notifyListeners();
    return device;
  }

  @override
  Future<void> rejectPairing() async {
    final _PendingJoin pending = _requirePendingJoin();
    await executeNodeCommand(
      _channel,
      node.RejectPairingCommand(code: pending.code),
    );

    _closeSession();
    notifyListeners();
  }

  @override
  Future<void> cancelPairing() async {
    final String? code = _sessionCode;
    if (code == null || findActiveSession() == null) {
      throw StateError(noShowingPairingCode);
    }

    await executeNodeCommand(_channel, node.CancelPairingCommand(code: code));

    _closeSession();
    notifyListeners();
  }

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

    final node.PendingJoin pending = await executeNodeCommand(
      _channel,
      node.JoinWithCodeCommand(
        serverAddress: serverAddress,
        code: code,
        deviceName: deviceName,
        role: mapDeviceRoleToNode(role),
      ),
    );

    try {
      return await _waitForJoinAnswer(pending);
    } finally {
      _waitingJoin = null;
      notifyListeners();
    }
  }

  @override
  WaitingJoin? findWaitingJoin() => _waitingJoin;

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

    final node.AccountSummary account = await executeNodeCommand(
      _channel,
      node.CreateHostedAccountCommand(
        workspaceName: workspaceName,
        deviceName: deviceName,
        role: mapDeviceRoleToNode(role),
      ),
    );
    return mapPairingOutcomeFromNode(
      account,
      runnerLabels: _runnerLabels,
      approverName: null,
    );
  }

  @override
  void dispose() {
    _closeSession();
    super.dispose();
  }

  void _tickCountdown(Timer timer) {
    final String? code = _sessionCode;
    if (code == null || findActiveSession() == null) {
      timer.cancel();
      notifyListeners();
      return;
    }

    notifyListeners();
    if (_request == null && !_isReadingRequest) {
      _isReadingRequest = true;
      unawaited(_readPairingRequest(code).whenComplete(_finishReadingRequest));
    }
  }

  Future<void> _readPairingRequest(String code) async {
    final node.PairingRequestScreen? screen =
        await readPairingRequestWhileCurrent(
          channel: _channel,
          code: code,
          isCurrentCode: _isCurrentCode,
        );
    final node.JoiningDevice? joining = screen?.joining;
    if (screen == null || joining == null || !_isCurrentCode(code)) {
      return;
    }

    _joining = joining;
    _request = mapPairingRequestFromNode(
      joining,
      codeUsed: screen.displayCode,
    );
    notifyListeners();
  }

  void _finishReadingRequest() {
    _isReadingRequest = false;
  }

  bool _isCurrentCode(String code) => code == _sessionCode;

  _PendingJoin _requirePendingJoin() {
    final String? code = _sessionCode;
    final node.JoiningDevice? joining = _joining;
    if (code == null || joining == null) {
      throw StateError('No device is waiting to be paired');
    }
    return (code: code, joining: joining);
  }

  Future<PairingOutcome> _waitForJoinAnswer(node.PendingJoin pending) async {
    while (true) {
      await Future<void>.delayed(_pollInterval);
      final node.JoinStatusView status = await executeNodeCommand(
        _channel,
        const node.JoinStatusCommand(),
      );
      switch (status) {
        case node.JoinWaiting():
          _showWaitingJoin(mapWaitingJoinFromNode(pending, status));
          continue;
        case node.JoinApproved(:final node.AccountSummary account):
          return mapPairingOutcomeFromNode(
            account,
            runnerLabels: _runnerLabels,
            approverName: await findApproverName(
              channel: _channel,
              account: account,
            ),
          );
        case node.JoinRejected():
          throw StateError('The other device rejected this pairing');
        case node.JoinExpired():
          throw StateError('The pairing code expired before it was approved');
      }
    }
  }

  void _showWaitingJoin(WaitingJoin? waitingJoin) {
    if (waitingJoin == null || _waitingJoin != null) {
      return;
    }
    _waitingJoin = waitingJoin;
    notifyListeners();
  }

  void _closeSession() {
    _countdown?.cancel();
    _countdown = null;
    _session = null;
    _sessionCode = null;
    _joining = null;
    _request = null;
  }
}
