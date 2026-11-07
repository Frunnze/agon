import 'dart:convert';
import 'dart:math';

import '../../../bridge/support/node_json_primitives.dart';
import '../../../bridge/support/random_account_json.dart';
import '../../../bridge/support/random_catalog_json.dart';
import '../../../bridge/support/scripted_node_transport.dart';
import 'simulated_server_group.dart';
import 'simulated_work_node.dart';

const String _workspacesField = 'workspaces';
const String _acceptingField = 'accepting_new_runs';
const String _localPlace = 'local_process';
const String simulatedNotARunnerMessage = 'this device cannot run tasks';
const String _revokedField = 'revoked';
const String _selfRevokeRefusal =
    'the app server answered 403: a device cannot revoke itself';
const String _alreadyRevokedRefusal =
    'the app server answered 409: the device is already revoked';
const String _revokedJoinRefusal =
    'the app server answered 409: the device is revoked';
const String _alreadyMemberRefusal =
    'the app server answered 409: the device is already in the workspace';
const String _missingKeyRefusal = 'this device holds no key for workspace';
const String _notMemberRefusal =
    'the app server answered 404: the workspace member was not found';
const String _genesisHash =
    '0000000000000000000000000000000000000000000000000000000000000000';

final class SimulatedDeviceNode {
  SimulatedDeviceNode({required this.thisDeviceId});

  final String thisDeviceId;
  final Map<String, WireRecord> devices = <String, WireRecord>{};
  final Map<String, WireRecord> runners = <String, WireRecord>{};
  final List<WireRecord> auditChain = <WireRecord>[];
  final List<String> receivedCommands = <String>[];
  bool isAuditIntact = true;
  String? peerProblem;
  String? runnerProblem;
  WireRecord? runnerSettings;
  List<WireRecord>? runnerOffers;

  String answer(String inputJson) {
    final WireRecord command = jsonDecode(inputJson) as WireRecord;
    final String name = command['command']! as String;
    receivedCommands.add(name);
    return switch (name) {
      'list_devices' => encodeSuccessReply(_listDevices()),
      'revoke_device' => _changeDevice(command, _revoke),
      'add_device_to_workspace' => _changeDevice(command, _addWorkspace),
      'remove_device_from_workspace' => _changeDevice(
        command,
        _removeWorkspace,
      ),
      'list_runners' => encodeSuccessReply(_listRunners()),
      'pause_runner' => _setAccepting(command, isAccepting: false),
      'resume_runner' => _setAccepting(command, isAccepting: true),
      'choose_agent_offers' => _chooseAgentOffers(command),
      'list_audit' => encodeSuccessReply(_listAudit()),
      'status' => encodeSuccessReply(_readStatus()),
      _ => encodeErrorReply('unknown command: $name'),
    };
  }

  String addDeviceFromElsewhere(Random random) {
    final WireRecord device = randomDeviceJson(random);
    final String deviceId = randomDeviceIdText(random);
    device['id'] = deviceId;
    devices[deviceId] = device;
    return deviceId;
  }

  String addRunnerFromElsewhere(Random random) {
    final WireRecord runner = randomRunnerJson(random);
    final String deviceId = randomDeviceIdText(random);
    runner['device_id'] = deviceId;
    runners[deviceId] = runner;
    return deviceId;
  }

  void appendAuditEntry(Random random) {
    final WireRecord entry = randomAuditEntryJson(random);
    entry['index'] = auditChain.length;
    auditChain.add(entry);
  }

  List<Object?> _listDevices() {
    return <Object?>[
      for (final WireRecord device in devices.values)
        <String, Object?>{
          'device': device,
          'is_this_device': device['id'] == thisDeviceId,
          'workspace_names': <Object?>[],
          'peer_address_verified': false,
        },
    ];
  }

  String _changeDevice(
    WireRecord command,
    String Function(WireRecord device, WireRecord command) change,
  ) {
    final WireRecord? device = devices[command['device_id']];
    if (device == null) {
      return encodeErrorReply('device ${command['device_id']} was not found');
    }
    return change(device, command);
  }

  String _revoke(WireRecord device, WireRecord command) {
    if (device['id'] == thisDeviceId) {
      return encodeErrorReply(_selfRevokeRefusal);
    }
    if (device[_revokedField] == true) {
      return encodeErrorReply(_alreadyRevokedRefusal);
    }

    device[_revokedField] = true;
    return encodeSuccessReply(null);
  }

  String _addWorkspace(WireRecord device, WireRecord command) {
    final List<Object?> workspaces =
        device[_workspacesField]! as List<Object?>;
    final Object? workspaceId = command['workspace_id'];
    if (!_holdsWorkspaceKey(workspaceId)) {
      return encodeErrorReply('$_missingKeyRefusal $workspaceId');
    }
    if (device[_revokedField] == true) {
      return encodeErrorReply(_revokedJoinRefusal);
    }
    if (workspaces.contains(command['workspace_id'])) {
      return encodeErrorReply(_alreadyMemberRefusal);
    }

    workspaces.add(command['workspace_id']);
    return encodeSuccessReply(null);
  }

  bool _holdsWorkspaceKey(Object? workspaceId) {
    final WireRecord? thisDevice = devices[thisDeviceId];
    if (thisDevice == null) {
      return false;
    }
    final List<Object?> keys = thisDevice[_workspacesField]! as List<Object?>;
    return keys.contains(workspaceId);
  }

  String _removeWorkspace(WireRecord device, WireRecord command) {
    final List<Object?> workspaces =
        device[_workspacesField]! as List<Object?>;
    if (!workspaces.contains(command['workspace_id'])) {
      return encodeErrorReply(_notMemberRefusal);
    }

    workspaces.removeWhere(
      (Object? joined) => joined == command['workspace_id'],
    );
    return encodeSuccessReply(null);
  }

  WireRecord _listRunners() {
    final List<Object?> views = <Object?>[
      for (final WireRecord runner in runners.values)
        <String, Object?>{
          'runner': runner,
          'device_name': simulatedProjectName,
          'free_slots': 0,
          'peer_address_verified': false,
        },
    ];
    return <String, Object?>{
      'summary': <String, Object?>{
        'runner_count': views.length,
        'online_count': 0,
        'free_slot_count': 0,
      },
      'summary_text': '',
      'runners': views,
      'this_device_problem': runnerProblem,
      'this_device_settings': runnerSettings,
      'this_device_offers': runnerOffers,
    };
  }

  String _chooseAgentOffers(WireRecord command) {
    if (runnerSettings == null) {
      return encodeErrorReply(simulatedNotARunnerMessage);
    }
    final List<Object?> places = command['offers']! as List<Object?>;
    runnerOffers = <WireRecord>[
      for (final Object? place in places)
        <String, Object?>{'place': place, 'problem': null},
    ];
    if (places.contains(_localPlace)) {
      runnerProblem = null;
    }
    return encodeSuccessReply(null);
  }

  String _setAccepting(WireRecord command, {required bool isAccepting}) {
    final WireRecord? runner = runners[command['device_id']];
    if (runner == null) {
      return encodeErrorReply('runner ${command['device_id']} was not found');
    }
    runner[_acceptingField] = isAccepting;
    return encodeSuccessReply(null);
  }

  WireRecord _readStatus() {
    return <String, Object?>{
      'server_address': null,
      'server_reachable': true,
      'device_id': thisDeviceId,
      'account': null,
      'pending_join': null,
      'peer': <String, Object?>{
        'published_address': null,
        'problem': peerProblem,
      },
      'runner_settings': runnerSettings,
      'app_servers': describeStandaloneServer(),
    };
  }

  WireRecord _listAudit() {
    final String headHash = auditChain.isEmpty
        ? _genesisHash
        : auditChain.last['hash']! as String;
    return <String, Object?>{
      'entries': auditChain,
      'entry_count': auditChain.length,
      'head_hash': headHash,
      'intact': isAuditIntact,
    };
  }
}
