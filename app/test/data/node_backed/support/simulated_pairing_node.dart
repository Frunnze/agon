import 'package:agent_orchestration/bridge/node/node_command_channel.dart';

import 'simulated_node_replies.dart';
import 'simulated_protected_files.dart';

const String simulatedPairingCode = '4F7K2Q';
const String simulatedDisplayCode = '4F7-K2Q';
const String simulatedApproverId = 'simulated-approver';
const String simulatedApproverName = 'office-mac';
const List<int> simulatedJoiningKey = <int>[9, 8, 7];
const List<String> simulatedWords = <String>['amber', 'cedar', 'lunar', 'oak'];
const int simulatedPollsBeforeReveal = 1;

final class SimulatedPairingNode {
  SimulatedPairingNode({
    required this.startedAt,
    required this.expiresAt,
    required this.pollsBeforeJoin,
    required this.joinPollsBeforeAnswer,
    required this.joinAnswer,
  });

  final String startedAt;
  final String expiresAt;
  final int pollsBeforeJoin;
  final int joinPollsBeforeAnswer;
  final String joinAnswer;
  final List<Map<String, Object?>> devices = <Map<String, Object?>>[];
  final List<Object?> approvedWorkspaceIds = <Object?>[];
  int pairingRequestPollCount = 0;
  int joinStatusPollCount = 0;
  int rejectedCount = 0;
  final List<Object?> cancelledCodes = <Object?>[];
  final List<Object?> joinServerAddresses = <Object?>[];
  bool hasAccount = false;
  String? rendezvousProblem;

  late final NodeCommandChannel channel = buildSimulatedChannel(answer);

  late final Map<String, SimulatedHandler> _handlers =
      <String, SimulatedHandler>{
        'start_pairing': _startPairing,
        'pairing_request': _readPairingRequest,
        'approve_pairing': _approvePairing,
        'reject_pairing': _rejectPairing,
        'cancel_pairing': _cancelPairing,
        'list_devices': _listDevices,
        'join_with_code': _joinWithCode,
        'join_status': _readJoinStatus,
        'create_hosted_account': _createHostedAccount,
      };

  String answer(String inputJson) {
    return answerSimulatedCommand(
      inputJson: inputJson,
      handlers: _handlers,
      failingCommands: const <String>{},
    );
  }

  Object? _startPairing(SimulatedCommand command) {
    pairingRequestPollCount = 0;
    return <String, Object?>{
      ..._buildPairingScreen(joining: null),
      'rendezvous_problem': rendezvousProblem,
    };
  }

  Object? _readPairingRequest(SimulatedCommand command) {
    _requirePairingCode(command);
    if (cancelledCodes.contains(command['code'])) {
      throw const SimulatedNodeFailure(
        'the app server answered 404: the pairing session ended',
      );
    }
    pairingRequestPollCount += 1;
    final bool hasJoined = pairingRequestPollCount > pollsBeforeJoin;
    return _buildPairingScreen(joining: hasJoined ? _joiningJson : null);
  }

  Object? _approvePairing(SimulatedCommand command) {
    _requirePairingCode(command);
    approvedWorkspaceIds.addAll(command['workspace_ids'] as List<Object?>);
    devices.add(
      buildSimulatedDeviceJson(
        deviceId: 'joined-${devices.length}',
        name: 'joining-phone',
        sealingPublicKey: simulatedJoiningKey,
        approvedBy: simulatedApproverId,
      ),
    );
    return null;
  }

  Object? _rejectPairing(SimulatedCommand command) {
    _requirePairingCode(command);
    rejectedCount += 1;
    return null;
  }

  Object? _cancelPairing(SimulatedCommand command) {
    _requirePairingCode(command);
    cancelledCodes.add(command['code']);
    return null;
  }

  Object? _listDevices(SimulatedCommand command) {
    final Map<String, Object?> approver = buildSimulatedDeviceJson(
      deviceId: simulatedApproverId,
      name: simulatedApproverName,
      sealingPublicKey: const <int>[1],
      approvedBy: null,
    );
    return <Object?>[
      for (final Map<String, Object?> device in <Map<String, Object?>>[
        approver,
        ...devices,
      ])
        <String, Object?>{
          'device': device,
          'is_this_device': device['id'] == simulatedApproverId,
          'peer_address_verified': false,
          'workspace_names': <String>[],
        },
    ];
  }

  Object? _joinWithCode(SimulatedCommand command) {
    joinStatusPollCount = 0;
    joinServerAddresses.add(command['server_address']);
    return <String, Object?>{
      'join_id': 'join-1',
      'display_code': simulatedDisplayCode,
    };
  }

  Object? _readJoinStatus(SimulatedCommand command) {
    joinStatusPollCount += 1;
    if (joinStatusPollCount <= joinPollsBeforeAnswer) {
      final bool hasApproverRevealed =
          joinStatusPollCount > simulatedPollsBeforeReveal;
      return <String, Object?>{
        'state': 'waiting',
        'fingerprint_words': hasApproverRevealed
            ? simulatedWords
            : const <String>[],
      };
    }
    if (joinAnswer != 'approved') {
      return <String, Object?>{
        'state': joinAnswer,
        'fingerprint_words': simulatedWords,
      };
    }
    return <String, Object?>{
      'state': 'approved',
      'fingerprint_words': simulatedWords,
      ..._buildAccountJson(
        deviceName: 'joining-phone',
        workspaceName: 'home',
        approvedBy: simulatedApproverId,
      ),
    };
  }

  Object? _createHostedAccount(SimulatedCommand command) {
    if (hasAccount) {
      throw const SimulatedNodeFailure('this device already has an account');
    }
    hasAccount = true;
    return _buildAccountJson(
      deviceName: command['device_name'] as String,
      workspaceName: command['workspace_name'] as String,
      approvedBy: null,
    );
  }

  Map<String, Object?> _buildPairingScreen({
    required Map<String, Object?>? joining,
  }) {
    return <String, Object?>{
      'code': simulatedPairingCode,
      'display_code': simulatedDisplayCode,
      'started_at': startedAt,
      'expires_at': expiresAt,
      'joining': joining,
    };
  }

  void _requirePairingCode(SimulatedCommand command) {
    if (command['code'] != simulatedPairingCode) {
      throw const SimulatedNodeFailure(
        'the pairing code does not match the session',
      );
    }
  }
}

const Map<String, Object?> _joiningJson = <String, Object?>{
  'name': 'joining-phone',
  'role': 'runner',
  'kind': 'phone',
  'key_kind': 'secure_enclave',
  'sealing_public_key': simulatedJoiningKey,
  'fingerprint_words': simulatedWords,
};

Map<String, Object?> _buildAccountJson({
  required String deviceName,
  required String workspaceName,
  required String? approvedBy,
}) {
  return <String, Object?>{
    'device': buildSimulatedDeviceJson(
      deviceId: 'account-device',
      name: deviceName,
      sealingPublicKey: simulatedJoiningKey,
      approvedBy: approvedBy,
    ),
    'workspaces': <Object?>[
      <String, Object?>{
        'id': 'workspace-of-$workspaceName',
        'name': workspaceName,
        'app_server_address': 'http://127.0.0.1:7070',
        'protected_files': buildSimulatedProtectedFilesJson(
          simulatedDefaultProtectedFiles,
        ),
      },
    ],
  };
}
