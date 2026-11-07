import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/repository_files.dart';

import '../../support/random_inputs.dart';
import 'support/repository_file_inputs.dart';

const List<String> _caseVariants = <String>['src', 'Src', 'SRC', 'sRc'];
const List<String> _codePointNames = <String>[
  '\u{1F600}.txt',
  '\u{FF41}.txt',
  '\u{E000}.txt',
  '\u{10000}.txt',
  'z.txt',
];

const int _largestNameCount = 6;
const int _highestBasicPlaneStart = 0xE000;
const int _highBasicPlaneSpan = 0x1000;
const int _firstHighPlaneCodePoint = 0x10000;
const int _highPlaneSpan = 0x10000;
const List<String> _caselessCharacters = <String>[
  '0',
  '7',
  '_',
  '~',
  '\u{E000}',
  '\u{FF10}',
  '\u{10000}',
  '\u{1F600}',
  '\u{20000}',
];

String _randomCaselessName(Random random) {
  final StringBuffer name = StringBuffer();
  final int length = 1 + random.nextInt(3);
  for (int i = 0; i < length; i += 1) {
    name.write(pickOne(random, _caselessCharacters));
  }
  return name.toString();
}

FakeFileRepository _buildRootFiles(List<String> names) {
  return buildFileRepository(<FakeRepositoryFile>[
    for (final String name in names)
      FakeRepositoryFile(
        repositoryAddress: fileTestAddress,
        path: name,
        size: name.length,
        preview: const TextFilePreview(''),
      ),
  ]);
}

void main() {
  test('test_sort_by_name_property_folders_come_before_files', () async {
    final Random random = seededRandom(64710);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<FakeRepositoryFile> files = randomRepositoryFiles(
        random,
        address: fileTestAddress,
      );
      final List<RepositoryEntry> root = await listFileTestFolder(
        buildFileRepository(files),
        '',
      );

      final List<RepositoryEntryKind> kinds = <RepositoryEntryKind>[
        for (final RepositoryEntry entry in root) entry.kind,
      ];
      final int firstFile = kinds.indexOf(RepositoryEntryKind.file);
      if (firstFile >= 0) {
        expect(kinds.skip(firstFile), everyElement(RepositoryEntryKind.file));
      }
    }
  });

  test('test_sort_by_name_property_does_not_depend_on_seed_order', () async {
    final Random random = seededRandom(64711);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<FakeRepositoryFile> files = randomRepositoryFiles(
        random,
        address: fileTestAddress,
      );
      final List<FakeRepositoryFile> shuffled = List<FakeRepositoryFile>.of(
        files,
      );
      shuffled.shuffle(random);
      final String folder = pickOne(random, listEveryFileTestFolder(files));

      final List<RepositoryEntry> fromSeeds = await listFileTestFolder(
        buildFileRepository(files),
        folder,
      );
      final List<RepositoryEntry> fromShuffled = await listFileTestFolder(
        buildFileRepository(shuffled),
        folder,
      );

      expect(
        describeListedEntries(fromShuffled),
        orderedEquals(describeListedEntries(fromSeeds)),
      );
    }
  });

  test('test_compare_names_property_ignores_case_first', () async {
    final Random random = seededRandom(64713);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String upper = pickOne(random, <String>['B.ts', 'Z', 'Middle']);
      final String lower = pickOne(random, <String>['a.ts', 'apple', 'aa']);
      final List<String> names = <String>[upper, lower];
      names.shuffle(random);

      final List<RepositoryEntry> root = await listFileTestFolder(
        _buildRootFiles(names),
        '',
      );

      expect(describeEntryNames(root), <String>[lower, upper]);
    }
  });

  test('test_compare_names_property_breaks_case_ties_by_code_point', () async {
    final Random random = seededRandom(64714);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> names = List<String>.of(_caseVariants);
      names.shuffle(random);

      final List<RepositoryEntry> root = await listFileTestFolder(
        _buildRootFiles(names),
        '',
      );

      expect(describeEntryNames(root), <String>['SRC', 'Src', 'sRc', 'src']);
    }
  });

  test('test_compare_names_property_orders_by_code_point_like_the_'
      'node', () async {
    final Random random = seededRandom(64715);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> names = List<String>.of(_codePointNames);
      names.shuffle(random);

      final List<RepositoryEntry> root = await listFileTestFolder(
        _buildRootFiles(names),
        '',
      );

      expect(describeEntryNames(root), <String>[
        'z.txt',
        '\u{E000}.txt',
        '\u{FF41}.txt',
        '\u{10000}.txt',
        '\u{1F600}.txt',
      ]);
    }
  });

  test('test_compare_code_points_property_orders_caseless_names_by_code_'
      'point', () async {
    final Random random = seededRandom(64716);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Set<String> names = <String>{};
      final int nameCount = 1 + random.nextInt(_largestNameCount);
      for (int name = 0; name < nameCount; name += 1) {
        names.add(_randomCaselessName(random));
      }
      final List<String> expected = names.toList();
      expected.sort(compareFileTestCodePoints);

      final List<RepositoryEntry> root = await listFileTestFolder(
        _buildRootFiles(names.toList()),
        '',
      );

      expect(describeEntryNames(root), expected);
    }
  });

  test('test_compare_code_points_property_a_prefix_comes_first', () async {
    final Random random = seededRandom(64717);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String prefix = _randomCaselessName(random);
      final String longer = '$prefix${_randomCaselessName(random)}';
      final List<String> names = <String>[longer, prefix];
      names.shuffle(random);

      final List<RepositoryEntry> root = await listFileTestFolder(
        _buildRootFiles(names),
        '',
      );

      expect(describeEntryNames(root), <String>[prefix, longer]);
    }
  });

  test('test_compare_code_points_property_high_plane_names_come_after_'
      'every_basic_plane_name', () async {
    final Random random = seededRandom(64718);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String basicPlane = String.fromCharCode(
        _highestBasicPlaneStart + random.nextInt(_highBasicPlaneSpan),
      );
      final String highPlane = String.fromCharCode(
        _firstHighPlaneCodePoint + random.nextInt(_highPlaneSpan),
      );
      final List<String> names = <String>[highPlane, basicPlane];
      names.shuffle(random);

      final List<RepositoryEntry> root = await listFileTestFolder(
        _buildRootFiles(names),
        '',
      );

      expect(describeEntryNames(root), <String>[basicPlane, highPlane]);
    }
  });
}
