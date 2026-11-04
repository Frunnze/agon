import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

const List<int> _sampleSigningKey = <int>[1, 2, 3, 4];
const List<int> _sampleSealingKey = <int>[5, 6, 7, 8];
const int _oldMacbookPairingYear = 2026;
const int _oldMacbookPairingMonth = 3;
const int _oldMacbookPairingDay = 12;

const List<WorkspaceId> _acmeAndPersonal = <WorkspaceId>[
  GalleryWorkspaceIds.acme,
  GalleryWorkspaceIds.personal,
];
const List<WorkspaceId> _acmeOnly = <WorkspaceId>[GalleryWorkspaceIds.acme];

Device _buildDevice({
  required DeviceId id,
  required String name,
  required DeviceRole role,
  required DeviceKind kind,
  required HardwareKeyKind keyKind,
  required List<WorkspaceId> workspaces,
  required DateTime pairedAt,
  required DateTime lastSeen,
}) {
  return Device(
    id: id,
    name: name,
    role: role,
    kind: kind,
    keyKind: keyKind,
    signingPublicKey: _sampleSigningKey,
    sealingPublicKey: _sampleSealingKey,
    workspaces: workspaces,
    pairedAt: pairedAt,
    approvedBy: id == GalleryDeviceIds.airLaptop
        ? null
        : GalleryDeviceIds.airLaptop,
    lastSeen: lastSeen,
    revoked: false,
  );
}

final List<Device> galleryDevices = List<Device>.unmodifiable(<Device>[
  _buildDevice(
    id: GalleryDeviceIds.airLaptop,
    name: 'air-laptop',
    role: DeviceRole.client,
    kind: DeviceKind.computer,
    keyKind: HardwareKeyKind.secureEnclave,
    workspaces: _acmeAndPersonal,
    pairedAt: galleryDaysAgo(300),
    lastSeen: galleryNow,
  ),
  _buildDevice(
    id: GalleryDeviceIds.macStudio,
    name: 'mac-studio',
    role: DeviceRole.runner,
    kind: DeviceKind.computer,
    keyKind: HardwareKeyKind.secureEnclave,
    workspaces: _acmeAndPersonal,
    pairedAt: galleryDaysAgo(200),
    lastSeen: galleryNow,
  ),
  _buildDevice(
    id: GalleryDeviceIds.officeServer,
    name: 'office-server',
    role: DeviceRole.runner,
    kind: DeviceKind.computer,
    keyKind: HardwareKeyKind.tpm,
    workspaces: _acmeOnly,
    pairedAt: galleryDaysAgo(150),
    lastSeen: galleryNow,
  ),
  _buildDevice(
    id: GalleryDeviceIds.gpuBox,
    name: 'gpu-box',
    role: DeviceRole.runner,
    kind: DeviceKind.computer,
    keyKind: HardwareKeyKind.tpm,
    workspaces: _acmeOnly,
    pairedAt: galleryDaysAgo(2),
    lastSeen: galleryNow.subtract(const Duration(minutes: 1)),
  ),
  _buildDevice(
    id: GalleryDeviceIds.pixelPhone,
    name: 'pixel-phone',
    role: DeviceRole.client,
    kind: DeviceKind.phone,
    keyKind: HardwareKeyKind.strongBox,
    workspaces: _acmeAndPersonal,
    pairedAt: galleryDaysAgo(100),
    lastSeen: galleryNow.subtract(const Duration(hours: 2)),
  ),
  _buildDevice(
    id: GalleryDeviceIds.oldMacbook,
    name: 'old-macbook',
    role: DeviceRole.clientAndRunner,
    kind: DeviceKind.computer,
    keyKind: HardwareKeyKind.secureEnclave,
    workspaces: _acmeOnly,
    pairedAt: DateTime(
      _oldMacbookPairingYear,
      _oldMacbookPairingMonth,
      _oldMacbookPairingDay,
    ),
    lastSeen: galleryDaysAgo(3),
  ),
  _buildDevice(
    id: GalleryDeviceIds.mainMac,
    name: 'main-mac',
    role: DeviceRole.client,
    kind: DeviceKind.computer,
    keyKind: HardwareKeyKind.secureEnclave,
    workspaces: _acmeAndPersonal,
    pairedAt: galleryDaysAgo(250),
    lastSeen: galleryNow,
  ),
]);
