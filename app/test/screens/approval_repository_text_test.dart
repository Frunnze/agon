import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/rules/local_folder_address.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/approvals/approval_text.dart';

import '../support/random_inputs.dart';

const List<String> _folderNames = <String>['hello-counter', 'billing', 'app'];
const List<String> _webAddresses = <String>[
  'github.com/acme/app',
  'gitlab.com/team/billing',
];

void main() {
  test(
    'test_describe_approval_repository_property_names_folder_and_device',
    () {
      final Random random = seededRandom(8401);
      final DeviceNames deviceNames = DeviceNames(galleryDevices);

      for (int i = 0; i < propertyIterations; i += 1) {
        final Device device = pickOne(random, galleryDevices);
        final String folder = pickOne(random, _folderNames);
        final String address = renderLocalFolderAddress(
          deviceId: device.id,
          path: '/Users/someone/code/${random.nextInt(100)}/$folder',
        );

        final String label = describeApprovalRepository(address, deviceNames);

        expect(label, '$folder on ${device.name}');
        expect(label, isNot(contains('local:')));
      }
    },
  );

  test('test_describe_approval_repository_property_keeps_web_addresses', () {
    final Random random = seededRandom(8402);
    final DeviceNames deviceNames = DeviceNames(galleryDevices);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String address = pickOne(random, _webAddresses);

      expect(describeApprovalRepository(address, deviceNames), address);
    }
  });
}
