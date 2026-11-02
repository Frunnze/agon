import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/rules/local_folder_address.dart';

import '../../support/random_inputs.dart';

const List<String> _folderNames = <String>['billing', 'app', 'My Code'];
const List<String> _trailingSeparators = <String>['', '/', '//'];

FakeDeviceRepository _buildRepository() {
  return FakeDeviceRepository(
    devices: galleryDevices,
    currentDeviceId: GalleryDeviceIds.airLaptop,
    peerAddressProblem: null,
  );
}

void main() {
  test('test_check_local_folder_property_names_this_device_folder', () async {
    final Random random = seededRandom(9301);
    final FakeDeviceRepository repository = _buildRepository();

    for (int i = 0; i < propertyIterations; i += 1) {
      final String path = '/Users/someone/${pickOne(random, _folderNames)}';
      final String typed = '$path${pickOne(random, _trailingSeparators)}';

      final RepositoryDraft draft = await repository.checkLocalFolder(typed);

      final LocalFolderAddress? folder = parseLocalFolderAddress(
        draft.address,
      );
      expect(folder?.deviceId, GalleryDeviceIds.airLaptop);
      expect(folder?.path, path);
      expect(draft.defaultBranch, 'main');
    }
  });

  test('test_check_local_folder_property_refuses_relative_paths', () async {
    final Random random = seededRandom(9302);
    final FakeDeviceRepository repository = _buildRepository();

    for (int i = 0; i < propertyIterations; i += 1) {
      final String relative = pickOne(random, _folderNames);

      await expectLater(
        repository.checkLocalFolder(relative),
        throwsA(isA<StateError>()),
      );
    }
  });
}
