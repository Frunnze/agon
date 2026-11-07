import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/rules/local_folder_address.dart';

import '../../support/random_inputs.dart';

const List<String> _folderNames = <String>['billing', 'app', 'site-2'];

FakeDeviceRepository _buildRepository() {
  return FakeDeviceRepository(
    devices: galleryDevices,
    currentDeviceId: GalleryDeviceIds.airLaptop,
    peerAddressProblem: null,
    gitlessFolderPaths: const <String>{},
  );
}

void main() {
  test('test_create_local_folder_property_makes_a_git_folder_once', () async {
    final Random random = seededRandom(9311);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeDeviceRepository repository = _buildRepository();
      final String parent =
          '${Directory.systemTemp.path}/parent ${randomWordPhrase(random)}'
              .trimRight();
      final String name = pickOne(random, _folderNames);

      final CheckedFolder created = await repository.createLocalFolder(
        parent: parent,
        name: name,
      );

      final LocalFolderAddress? folder = parseLocalFolderAddress(
        created.repository.address,
      );
      expect(folder?.path, '$parent/$name');
      expect(folder?.deviceId, GalleryDeviceIds.airLaptop);
      expect(created.repository.defaultBranch, 'main');
      expect(created.hasStartedGit, isTrue);
      await expectLater(
        repository.createLocalFolder(parent: parent, name: name),
        throwsA(isA<StateError>()),
      );
    }
  });
}
