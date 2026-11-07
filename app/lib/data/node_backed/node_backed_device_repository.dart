import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/bridge/codecs/account_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/catalog_views.dart' as node;
import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart'
    as node;
import 'package:agent_orchestration/bridge/commands/account_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/commands/device_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/commands/project_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

const String _deviceKind = 'device';
const String _thisDeviceMissingProblem =
    'The node has not listed this device yet';
const Set<node.ChangeArea> _deviceAreas = <node.ChangeArea>{
  node.ChangeArea.devices,
  node.ChangeArea.workspaces,
};

final class NodeBackedDeviceRepository extends ChangeNotifier
    implements DeviceRepository, NodeSynchronized {
  NodeBackedDeviceRepository({required NodeCommandChannel channel})
    : _channel = channel;

  final NodeCommandChannel _channel;
  final FetchSequence _fetches = FetchSequence();
  List<Device> _devices = const <Device>[];
  DeviceId? _thisDeviceId;
  String? _peerAddressProblem;

  @override
  List<Device> listDevices() => _devices;

  @override
  Device findDevice(DeviceId deviceId) {
    return findRecord(
      _devices,
      matches: (Device device) => device.id == deviceId,
      kind: _deviceKind,
      identifier: deviceId.value,
    );
  }

  @override
  Device currentDevice() {
    final DeviceId? thisDeviceId = _thisDeviceId;
    if (thisDeviceId == null) {
      throw StateError(_thisDeviceMissingProblem);
    }
    return findDevice(thisDeviceId);
  }

  @override
  String? findPeerAddressProblem() => _peerAddressProblem;

  @override
  Future<CheckedFolder> checkLocalFolder(String path) async {
    final node.CheckedLocalFolder checked = await executeNodeCommand(
      _channel,
      node.CheckLocalFolderCommand(path: path),
    );
    return _mapCheckedFolder(checked);
  }

  @override
  Future<CheckedFolder> createLocalFolder({
    required String parent,
    required String name,
  }) async {
    final node.CheckedLocalFolder created = await executeNodeCommand(
      _channel,
      node.CreateLocalFolderCommand(parent: parent, folderName: name),
    );
    return _mapCheckedFolder(created);
  }

  CheckedFolder _mapCheckedFolder(node.CheckedLocalFolder checked) {
    return CheckedFolder(
      repository: RepositoryDraft(
        address: checked.address,
        defaultBranch: checked.defaultBranch,
      ),
      hasStartedGit: checked.hasStartedGit,
    );
  }

  @override
  Future<void> load() async {
    final int fetch = _fetches.startFetch();
    final List<node.DeviceView> views = await executeNodeCommand(
      _channel,
      const node.ListDevicesCommand(),
    );
    final List<Device> devices = <Device>[
      for (final node.DeviceView view in views) mapDeviceFromNode(view.device),
    ];
    DeviceId? thisDeviceId;
    for (final node.DeviceView view in views) {
      if (view.isThisDevice) {
        thisDeviceId = view.device.id;
      }
    }

    final node.StatusView status = await executeNodeCommand(
      _channel,
      const node.StatusCommand(),
    );
    if (!_fetches.acceptIfNewest(fetch)) {
      return;
    }

    _devices = List<Device>.unmodifiable(devices);
    _thisDeviceId = thisDeviceId;
    _peerAddressProblem = status.peer?.problem;
    notifyListeners();
  }

  @override
  Future<void> applyChange(node.ChangeTopic topic) async {
    if (isChangeInAreas(topic, _deviceAreas)) {
      await load();
    }
  }

  @override
  Future<Device> revokeDevice(DeviceId deviceId) async {
    await executeNodeCommand(
      _channel,
      node.RevokeDeviceCommand(deviceId: deviceId),
    );
    return _reloadDevice(deviceId);
  }

  @override
  Future<Device> addDeviceToWorkspace(
    DeviceId deviceId,
    WorkspaceId workspaceId,
  ) async {
    await executeNodeCommand(
      _channel,
      node.AddDeviceToWorkspaceCommand(
        workspaceId: workspaceId,
        deviceId: deviceId,
      ),
    );
    return _reloadDevice(deviceId);
  }

  @override
  Future<Device> removeDeviceFromWorkspace(
    DeviceId deviceId,
    WorkspaceId workspaceId,
  ) async {
    await executeNodeCommand(
      _channel,
      node.RemoveDeviceFromWorkspaceCommand(
        workspaceId: workspaceId,
        deviceId: deviceId,
      ),
    );
    return _reloadDevice(deviceId);
  }

  Future<Device> _reloadDevice(DeviceId deviceId) async {
    await load();
    return findDevice(deviceId);
  }
}
