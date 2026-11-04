import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/rules/local_folder_address.dart';

const String _deviceKind = 'device';
const String _unixRoot = '/';
const String _fakeCheckedOutBranch = 'main';

final class FakeDeviceRepository extends ChangeNotifier
    implements DeviceRepository {
  FakeDeviceRepository({
    required List<Device> devices,
    required DeviceId currentDeviceId,
    required String? peerAddressProblem,
    required Set<String> gitlessFolderPaths,
  }) : _devices = List<Device>.unmodifiable(devices),
       _currentDeviceId = currentDeviceId,
       _peerAddressProblem = peerAddressProblem,
       _gitlessFolderPaths = Set<String>.unmodifiable(gitlessFolderPaths) {
    findDevice(currentDeviceId);
  }

  final DeviceId _currentDeviceId;
  final String? _peerAddressProblem;
  final Set<String> _gitlessFolderPaths;
  Set<String> _createdFolderPaths = const <String>{};
  List<Device> _devices;

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
  Device currentDevice() => findDevice(_currentDeviceId);

  @override
  String? findPeerAddressProblem() => _peerAddressProblem;

  @override
  Future<CheckedFolder> checkLocalFolder(String path) async {
    String folderPath = path.trim();
    if (!folderPath.startsWith(_unixRoot)) {
      throw StateError('the folder "$path" is not an absolute path');
    }
    while (folderPath.length > 1 && folderPath.endsWith(_unixRoot)) {
      folderPath = folderPath.substring(0, folderPath.length - 1);
    }

    return CheckedFolder(
      repository: RepositoryDraft(
        address: renderLocalFolderAddress(
          deviceId: _currentDeviceId,
          path: folderPath,
        ),
        defaultBranch: _fakeCheckedOutBranch,
      ),
      hasStartedGit: _gitlessFolderPaths.contains(folderPath),
    );
  }

  @override
  Future<CheckedFolder> createLocalFolder({
    required String parent,
    required String name,
  }) async {
    final String folderPath = '$parent/$name';
    if (_createdFolderPaths.contains(folderPath)) {
      throw StateError(
        'the folder $folderPath already exists, so choose another name or '
        'place',
      );
    }
    _createdFolderPaths = <String>{..._createdFolderPaths, folderPath};

    return CheckedFolder(
      repository: RepositoryDraft(
        address: renderLocalFolderAddress(
          deviceId: _currentDeviceId,
          path: folderPath,
        ),
        defaultBranch: _fakeCheckedOutBranch,
      ),
      hasStartedGit: true,
    );
  }

  Future<Device> addPairedDevice(Device device) async {
    final bool isKnown = _devices.any(
      (Device candidate) => candidate.id == device.id,
    );
    if (isKnown) {
      throw StateError('Device ${device.name} is already paired');
    }

    _devices = appendRecord(_devices, device);
    notifyListeners();
    return device;
  }

  @override
  Future<Device> revokeDevice(DeviceId deviceId) async {
    if (deviceId == _currentDeviceId) {
      throw StateError('This device cannot revoke itself');
    }

    return _storeDevice(findDevice(deviceId).asRevoked());
  }

  @override
  Future<Device> addDeviceToWorkspace(
    DeviceId deviceId,
    WorkspaceId workspaceId,
  ) async {
    final Device device = findDevice(deviceId);
    if (device.workspaces.contains(workspaceId)) {
      return device;
    }

    return _storeDevice(
      device.withWorkspaces(<WorkspaceId>[...device.workspaces, workspaceId]),
    );
  }

  @override
  Future<Device> removeDeviceFromWorkspace(
    DeviceId deviceId,
    WorkspaceId workspaceId,
  ) async {
    final Device device = findDevice(deviceId);
    final List<WorkspaceId> remaining = device.workspaces
        .where((WorkspaceId candidate) => candidate != workspaceId)
        .toList();

    return _storeDevice(device.withWorkspaces(remaining));
  }

  Device _storeDevice(Device device) {
    _devices = replaceRecord(
      _devices,
      matches: (Device candidate) => candidate.id == device.id,
      replacement: device,
    );
    notifyListeners();
    return device;
  }
}
