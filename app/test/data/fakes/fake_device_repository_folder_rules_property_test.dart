import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/project.dart';

import '../../support/random_inputs.dart';
import 'support/device_inputs.dart';

const int _firstPrintableCodePoint = 0x20;
const int _deleteCodePoint = 0x7f;
const int _secondControlBlockSize = 0x21;
const List<String> _innerSpacedParts = <String>[
  ' lead',
  'in  side',
  'x ',
  ' ',
];
const List<String> _dottedParts = <String>['...', '.x', 'x.', '..x', 'x..'];
const List<String> _reservedParts = <String>['.', '..'];
const List<String> _paddedNames = <String>[' x', 'x ', '\t', '\u{3000}x'];
const List<String> _separatedNames = <String>['a/b', 'a\\b', '/', '\\'];
const List<String> _acceptedNames = <String>[
  'My Code',
  'café',
  '...',
  '.x',
  'Ünïcødé',
  'a..b',
];

String _insertPart(Random random, String path, String part) {
  final List<String> parts = path.substring(1).split('/');
  parts.insert(random.nextInt(parts.length), part);
  return '/${parts.join('/')}';
}

String _randomControlText(Random random) {
  final int codePoint = random.nextBool()
      ? random.nextInt(_firstPrintableCodePoint)
      : _deleteCodePoint + random.nextInt(_secondControlBlockSize);
  return String.fromCharCode(codePoint);
}

Future<String?> _checkPath(String path) async {
  final FakeDeviceRepository repository = buildFolderTestRepository(
    <String>{},
  );
  final CheckedFolder checked = await repository.checkLocalFolder(path);
  return readCheckedFolderPath(checked);
}

void main() {
  test('test_normalize_folder_path_property_a_created_folder_checks_to_the_'
      'same_address', () async {
    final Random random = seededRandom(65301);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeDeviceRepository repository = buildFolderTestRepository(
        <String>{},
      );
      final String parent = randomAbsoluteFolderPath(random);
      final CheckedFolder created = await repository.createLocalFolder(
        parent: '$parent${randomTrailingFolderNoise(random)}',
        name: pickOne(random, sampleFolderParts),
      );

      final CheckedFolder checked = await repository.checkLocalFolder(
        '${readCheckedFolderPath(created)}${randomTrailingFolderNoise(random)}',
      );

      expect(checked.repository.address, created.repository.address);
    }
  });

  test('test_normalize_folder_path_property_inner_white_space_is_'
      'kept', () async {
    final Random random = seededRandom(65302);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String path = _insertPart(
        random,
        '${randomAbsoluteFolderPath(random)}/end',
        pickOne(random, _innerSpacedParts),
      );

      expect(await _checkPath(path), path);
    }
  });

  test('test_normalize_folder_path_property_control_characters_anywhere_are_'
      'refused', () async {
    final Random random = seededRandom(65303);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String safePath = randomAbsoluteFolderPath(random);
      final int place = 1 + random.nextInt(safePath.length);
      final String hostile =
          '${safePath.substring(0, place)}${_randomControlText(random)}'
          '${safePath.substring(place)}/end';

      await expectLater(_checkPath(hostile), throwsStateError);
    }
  });

  test('test_is_unsafe_folder_part_property_empty_middle_parts_are_'
      'refused', () async {
    final Random random = seededRandom(65304);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String hostile = _insertPart(
        random,
        '${randomAbsoluteFolderPath(random)}/end',
        '',
      );

      await expectLater(_checkPath(hostile), throwsStateError);
    }
  });

  test('test_is_unsafe_folder_part_property_dot_parts_are_refused', () async {
    final Random random = seededRandom(65305);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String hostile = _insertPart(
        random,
        randomAbsoluteFolderPath(random),
        pickOne(random, _reservedParts),
      );

      await expectLater(_checkPath(hostile), throwsStateError);
    }
  });

  test('test_is_unsafe_folder_part_property_parts_that_merely_hold_dots_are_'
      'kept', () async {
    final Random random = seededRandom(65306);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String path = _insertPart(
        random,
        randomAbsoluteFolderPath(random),
        pickOne(random, _dottedParts),
      );

      expect(await _checkPath(path), path);
    }
  });

  test('test_require_safe_folder_name_property_padded_names_are_'
      'refused', () async {
    final Random random = seededRandom(65307);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeDeviceRepository repository = buildFolderTestRepository(
        <String>{},
      );

      await expectLater(
        repository.createLocalFolder(
          parent: randomAbsoluteFolderPath(random),
          name: pickOne(random, _paddedNames),
        ),
        throwsStateError,
      );
    }
  });

  test('test_require_safe_folder_name_property_separators_and_controls_are_'
      'refused', () async {
    final Random random = seededRandom(65308);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeDeviceRepository repository = buildFolderTestRepository(
        <String>{},
      );
      final String name = random.nextBool()
          ? pickOne(random, _separatedNames)
          : 'name${_randomControlText(random)}end';

      await expectLater(
        repository.createLocalFolder(
          parent: randomAbsoluteFolderPath(random),
          name: name,
        ),
        throwsStateError,
      );
    }
  });

  test('test_require_safe_folder_name_property_unicode_and_dotted_names_are_'
      'accepted', () async {
    final Random random = seededRandom(65309);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeDeviceRepository repository = buildFolderTestRepository(
        <String>{},
      );
      final String parent = randomAbsoluteFolderPath(random);
      final String name = pickOne(random, _acceptedNames);

      final CheckedFolder created = await repository.createLocalFolder(
        parent: parent,
        name: name,
      );

      expect(readCheckedFolderPath(created), '$parent/$name');
    }
  });
}
