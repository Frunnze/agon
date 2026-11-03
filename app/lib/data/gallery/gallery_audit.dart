import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/audit.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

const int galleryAuditEntryCount = 1284;

AuditEntry _buildAuditEntry({
  required int index,
  required DateTime at,
  required DeviceId deviceId,
  required String event,
  required String detail,
  required String hash,
  required String previousHash,
}) {
  return AuditEntry(
    index: index,
    at: at,
    deviceId: deviceId,
    event: event,
    detail: detail,
    previousHash: previousHash,
    hash: hash,
  );
}

final List<AuditEntry> galleryAuditEntries = List<AuditEntry>.unmodifiable(
  <AuditEntry>[
    _buildAuditEntry(
      index: 1283,
      at: galleryToday(14, 9),
      deviceId: GalleryDeviceIds.macStudio,
      event: 'Asked to push 3 commits',
      detail: 'release #42 · acme/app',
      hash: '9f3a6b1e8d2c4f7a0b5e9d3c1a7fc210',
      previousHash: '51be2c9a7f3d1e5b8c0a4f6d2e9b07d4',
    ),
    _buildAuditEntry(
      index: 1282,
      at: galleryToday(14, 4),
      deviceId: GalleryDeviceIds.officeServer,
      event: 'Finished step plan',
      detail: 'release #42',
      hash: '51be2c9a7f3d1e5b8c0a4f6d2e9b07d4',
      previousHash: 'c07e4d1b9a2f6c3e8b5d0a7f1e4c9a13',
    ),
    _buildAuditEntry(
      index: 1281,
      at: galleryToday(14, 2),
      deviceId: GalleryDeviceIds.airLaptop,
      event: 'Started workflow release',
      detail: 'release #42',
      hash: 'c07e4d1b9a2f6c3e8b5d0a7f1e4c9a13',
      previousHash: '7d22b8e1c4a9f3d6e0b2c5a8f1d4e581',
    ),
    _buildAuditEntry(
      index: 1280,
      at: galleryToday(13, 10),
      deviceId: GalleryDeviceIds.airLaptop,
      event: 'Changed workflow train-ranker',
      detail: 'Not signed yet',
      hash: '7d22b8e1c4a9f3d6e0b2c5a8f1d4e581',
      previousHash: '0e41c7a2f9b3d5e8a1c4f6b0d2e9d97c',
    ),
    _buildAuditEntry(
      index: 1279,
      at: galleryYesterday(11, 15),
      deviceId: GalleryDeviceIds.airLaptop,
      event: 'Denied deleting branch main',
      detail: 'docs-sync #117 · acme/docs',
      hash: '0e41c7a2f9b3d5e8a1c4f6b0d2e9d97c',
      previousHash: '2a9f5e1c8b4d7a0f3e6c9b2d5a8fb3c6',
    ),
    _buildAuditEntry(
      index: 1278,
      at: galleryDaysAgo(2),
      deviceId: GalleryDeviceIds.airLaptop,
      event: 'Paired gpu-box as a runner',
      detail: 'Approved',
      hash: '2a9f5e1c8b4d7a0f3e6c9b2d5a8fb3c6',
      previousHash: 'f81c3a5e7b9d2f4a6c8e0b1d3f5a7c9e',
    ),
  ],
);
