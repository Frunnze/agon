import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_runners.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/rules/device_roles.dart';
import 'package:agent_orchestration/data/rules/naming.dart';

import 'support/gallery_records.dart';

void main() {
  test('test_gallery_devices_property_names_are_valid_and_unique', () {
    final List<String> names = <String>[
      for (final Device device in galleryDevices) device.name,
    ];

    for (final String name in names) {
      expect(describeNameProblem(name), isNull, reason: name);
    }
    expect(hasNoRepeats(names), isTrue);
  });

  test('test_gallery_devices_property_ids_are_unique_node_ids', () {
    final List<DeviceId> identifiers = <DeviceId>[
      for (final Device device in galleryDevices) device.id,
    ];

    for (final DeviceId identifier in identifiers) {
      expect(identifier.value, matches(deviceIdentifierPattern));
    }
    expect(hasNoRepeats(identifiers), isTrue);
  });

  test('test_gallery_devices_property_belong_to_existing_workspaces', () {
    for (final Device device in galleryDevices) {
      expect(device.workspaces, isNotEmpty, reason: device.name);
      expect(hasNoRepeats(device.workspaces), isTrue, reason: device.name);
      for (final WorkspaceId workspaceId in device.workspaces) {
        findGalleryWorkspace(workspaceId);
      }
    }
  });

  test('test_gallery_devices_property_approved_by_an_earlier_client', () {
    final List<Device> founders = <Device>[
      for (final Device device in galleryDevices)
        if (device.approvedBy == null) device,
    ];

    expect(founders.length, 1);
    for (final Device device in galleryDevices) {
      final DeviceId? approverId = device.approvedBy;
      if (approverId == null) {
        continue;
      }
      final Device approver = findGalleryDevice(approverId);

      expect(approverId, isNot(device.id));
      expect(approver.role, isNot(DeviceRole.runner), reason: device.name);
      expect(approver.pairedAt.isAfter(device.pairedAt), isFalse);
    }
  });

  test('test_gallery_devices_property_seen_after_pairing_and_before_now', () {
    for (final Device device in galleryDevices) {
      expect(device.lastSeen.isBefore(device.pairedAt), isFalse);
      expect(
        device.lastSeen.isAfter(galleryNow),
        isFalse,
        reason: device.name,
      );
      expect(device.signingPublicKey, isNotEmpty);
      expect(device.sealingPublicKey, isNotEmpty);
    }
  });

  test('test_gallery_devices_property_every_runner_is_a_runner_device', () {
    for (final Runner runner in galleryRunners) {
      final Device device = findGalleryDevice(runner.deviceId);

      expect(roleRunsTasks(device.role), isTrue, reason: device.name);
      expect(device.kind, DeviceKind.computer);
      expect(device.revoked, isFalse);
    }
  });
}
