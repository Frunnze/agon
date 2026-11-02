import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/rules/local_folder_address.dart';

import '../../support/random_inputs.dart';

const List<String> _folderParts = <String>[
  'Users',
  'air',
  'code',
  'billing-ui',
  'My Projects',
  'a.b',
  'x_1',
];
const List<String> _hexDigits = <String>['0', '1', '7', 'a', 'c', 'f'];
const List<String> _githubForms = <String>[
  'github.com/acme/app',
  'https://github.com/acme/app.git',
  'git@github.com:acme/app.git',
  'acme/app',
];

String _randomDeviceId(Random random) {
  final StringBuffer buffer = StringBuffer();
  final int length = 1 + random.nextInt(32);
  for (int i = 0; i < length; i += 1) {
    buffer.write(pickOne(random, _hexDigits));
  }
  return buffer.toString();
}

List<String> _randomParts(Random random) {
  final int count = 1 + random.nextInt(4);
  return <String>[
    for (int i = 0; i < count; i += 1) pickOne(random, _folderParts),
  ];
}

String _randomFolderPath(Random random) {
  final List<String> parts = _randomParts(random);
  if (random.nextBool()) {
    return '/${parts.join('/')}';
  }
  return 'C:\\${parts.join('\\')}';
}

Repository _repositoryAt(String address) {
  return Repository(
    address: address,
    defaultBranch: 'main',
    agentAccess: AgentAccess.pushAfterApproval,
  );
}

void main() {
  test('test_parse_local_folder_address_property_reads_what_render_wrote', () {
    final Random random = seededRandom(9101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DeviceId deviceId = DeviceId(_randomDeviceId(random));
      final String path = _randomFolderPath(random);
      final String address = renderLocalFolderAddress(
        deviceId: deviceId,
        path: path,
      );

      final LocalFolderAddress? folder = parseLocalFolderAddress(address);

      expect(folder?.deviceId, deviceId);
      expect(folder?.path, path);
    }
    expect(
      renderLocalFolderAddress(
        deviceId: const DeviceId('3f2a9c'),
        path: '/Users/someone/billing',
      ),
      'local:3f2a9c:/Users/someone/billing',
    );
  });

  test('test_parse_local_folder_address_property_github_is_not_local', () {
    for (final String address in _githubForms) {
      expect(parseLocalFolderAddress(address), isNull, reason: address);
    }
  });

  test('test_parse_local_folder_address_fuzz_property_never_throws', () {
    final Random random = seededRandom(9102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String text = random.nextBool()
          ? 'local:${randomText(random)}'
          : randomText(random);

      final LocalFolderAddress? folder = parseLocalFolderAddress(text);

      if (folder != null) {
        expect(text, startsWith('local:'));
        expect(folder.deviceId.value, isNotEmpty);
        expect(folder.path, isNotEmpty);
      }
    }
  });

  test('test_describe_folder_name_property_names_the_last_part', () {
    final Random random = seededRandom(9103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> parts = _randomParts(random);
      final String trailing = pickOne(random, <String>['', '/', '\\']);
      final String unixPath = '/${parts.join('/')}$trailing';
      final String windowsPath = 'D:\\${parts.join('\\')}$trailing';

      expect(describeFolderName(unixPath), parts.last);
      expect(describeFolderName(windowsPath), parts.last);
    }
  });

  test('test_looks_like_folder_path_property_paths_are_not_addresses', () {
    final Random random = seededRandom(9104);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String path = _randomFolderPath(random);

      expect(looksLikeFolderPath('  $path '), isTrue, reason: path);
    }
    for (final String address in _githubForms) {
      expect(looksLikeFolderPath(address), isFalse, reason: address);
    }
    expect(looksLikeFolderPath('~/code/app'), isTrue);
  });

  test('test_find_local_folder_property_finds_the_first_folder', () {
    final Random random = seededRandom(9105);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DeviceId deviceId = DeviceId(_randomDeviceId(random));
      final String path = _randomFolderPath(random);
      final String folderAddress = renderLocalFolderAddress(
        deviceId: deviceId,
        path: path,
      );
      final List<Repository> remote = <Repository>[
        for (final String address in _githubForms.take(random.nextInt(3)))
          _repositoryAt(address),
      ];
      final bool hasFolder = random.nextBool();
      final List<Repository> repositories = <Repository>[
        ...remote,
        if (hasFolder) _repositoryAt(folderAddress),
      ];

      final LocalFolderAddress? found = findLocalFolder(repositories);

      expect(found?.deviceId, hasFolder ? deviceId : null);
      expect(found?.path, hasFolder ? path : null);
    }
  });
}
