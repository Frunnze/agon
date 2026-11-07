import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/native/native_library_source.dart';

import '../../support/random_inputs.dart';
import '../support/hostile_texts.dart';

const int _firstSeed = 6267000;
const String _rustLibraryName = 'orchestration_ffi';
const List<String> _supportedSystems = <String>[
  androidSystemName,
  linuxSystemName,
  windowsSystemName,
  macSystemName,
  iosSystemName,
];
const List<String> _dartOperatingSystemNames = <String>[
  'android',
  'linux',
  'windows',
  'macos',
  'ios',
];
const Map<String, String> _systemLibraryFileEndings = <String, String>{
  androidSystemName: 'lib$_rustLibraryName.so',
  linuxSystemName: 'lib$_rustLibraryName.so',
  windowsSystemName: '$_rustLibraryName.dll',
  macSystemName: '/Frameworks/lib$_rustLibraryName.dylib',
};

enum _SourceKind { linkedIntoProcess, libraryFile, processOrLibraryFile }

typedef _ReadSource = ({_SourceKind kind, String? path});

_ReadSource _readSource(NativeLibrarySource source) {
  return switch (source) {
    LinkedIntoProcess() => (kind: _SourceKind.linkedIntoProcess, path: null),
    LibraryFile(:final String path) => (
      kind: _SourceKind.libraryFile,
      path: path,
    ),
    LinkedIntoProcessOrLibraryFile(:final String path) => (
      kind: _SourceKind.processOrLibraryFile,
      path: path,
    ),
  };
}

NativeLibrarySource _buildSource(_SourceKind kind, String path) {
  return switch (kind) {
    _SourceKind.linkedIntoProcess => const LinkedIntoProcess(),
    _SourceKind.libraryFile => LibraryFile(path: path),
    _SourceKind.processOrLibraryFile => LinkedIntoProcessOrLibraryFile(
      path: path,
    ),
  };
}

List<String> _changedSpellings(String systemName) {
  return <String>[
    systemName.toUpperCase(),
    ' $systemName',
    '$systemName ',
    '$systemName\n',
    '${systemName[0].toUpperCase()}${systemName.substring(1)}',
    '$systemName$systemName',
  ];
}

void main() {
  test('test_native_library_source_constructor_property_one_kind_each', () {
    final Random random = seededRandom(_firstSeed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _SourceKind kind = pickOne(random, _SourceKind.values);
      final NativeLibrarySource source = _buildSource(
        kind,
        randomHostileText(random),
      );

      expect(_readSource(source).kind, kind);
    }
  });

  test('test_native_library_source_constructor_property_paths_survive', () {
    final Random random = seededRandom(_firstSeed + 1);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _SourceKind kind = pickOne(random, _SourceKind.values);
      final String path = randomHostileText(random);
      final _ReadSource readSource = _readSource(_buildSource(kind, path));

      if (kind == _SourceKind.linkedIntoProcess) {
        expect(readSource.path, isNull);
        continue;
      }
      expect(readSource.path, path);
    }
  });

  test('test_native_library_source_constructor_property_no_shared_state', () {
    final Random random = seededRandom(_firstSeed + 2);
    final List<String> paths = <String>[];
    final List<NativeLibrarySource> sources = <NativeLibrarySource>[];

    for (int i = 0; i < propertyIterations; i += 1) {
      final String path = randomHostileText(random);
      paths.add(path);
      sources.add(
        _buildSource(
          pickOne(random, <_SourceKind>[
            _SourceKind.libraryFile,
            _SourceKind.processOrLibraryFile,
          ]),
          path,
        ),
      );
    }

    for (int i = 0; i < sources.length; i += 1) {
      expect(_readSource(sources[i]).path, paths[i]);
    }
  });

  test('test_linked_into_process_constructor_property_is_one_constant', () {
    const NativeLibrarySource first = LinkedIntoProcess();
    const NativeLibrarySource second = LinkedIntoProcess();

    expect(identical(first, second), isTrue);
  });

  test('test_linked_into_process_constructor_property_carries_no_path', () {
    expect(_readSource(const LinkedIntoProcess()).path, isNull);
    expect(const LinkedIntoProcess(), isNot(isA<LibraryFile>()));
  });

  test('test_linked_into_process_constructor_property_is_chosen_for_ios', () {
    expect(
      chooseBundledLibrarySource(iosSystemName),
      isA<LinkedIntoProcess>(),
    );
  });

  test('test_library_file_constructor_property_keeps_the_path', () {
    final Random random = seededRandom(_firstSeed + 3);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String path = randomHostileText(random);

      expect(LibraryFile(path: path).path, path);
    }
  });

  test('test_library_file_constructor_property_is_not_process_linked', () {
    final Random random = seededRandom(_firstSeed + 4);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NativeLibrarySource source = LibraryFile(
        path: randomHostileText(random),
      );

      expect(_readSource(source).kind, _SourceKind.libraryFile);
    }
  });

  test('test_library_file_constructor_property_const_paths_are_shared', () {
    const LibraryFile first = LibraryFile(path: sharedObjectFileName);
    const LibraryFile second = LibraryFile(path: sharedObjectFileName);

    expect(identical(first, second), isTrue);
    expect(first.path, sharedObjectFileName);
  });

  test('test_linked_into_process_or_library_file_constructor_property_'
      'keeps_the_path', () {
    final Random random = seededRandom(_firstSeed + 5);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String path = randomHostileText(random);

      expect(LinkedIntoProcessOrLibraryFile(path: path).path, path);
    }
  });

  test('test_linked_into_process_or_library_file_constructor_property_'
      'is_its_own_kind', () {
    final Random random = seededRandom(_firstSeed + 6);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NativeLibrarySource source = LinkedIntoProcessOrLibraryFile(
        path: randomHostileText(random),
      );

      expect(_readSource(source).kind, _SourceKind.processOrLibraryFile);
      expect(source, isNot(isA<LibraryFile>()));
    }
  });

  test('test_linked_into_process_or_library_file_constructor_property_'
      'is_chosen_for_macos', () {
    final NativeLibrarySource source = chooseBundledLibrarySource(
      macSystemName,
    );

    expect(_readSource(source).kind, _SourceKind.processOrLibraryFile);
    expect(_readSource(source).path, macBundledLibraryPath);
  });

  test('test_choose_bundled_library_source_property_names_the_rust_crate', () {
    for (final MapEntry<String, String> system
        in _systemLibraryFileEndings.entries) {
      final _ReadSource source = _readSource(
        chooseBundledLibrarySource(system.key),
      );

      expect(source.path, endsWith(system.value), reason: system.key);
    }
    expect(_supportedSystems, orderedEquals(_dartOperatingSystemNames));
  });

  test('test_choose_bundled_library_source_property_exact_names_only', () {
    for (final String systemName in _supportedSystems) {
      for (final String spelling in _changedSpellings(systemName)) {
        expect(
          () => chooseBundledLibrarySource(spelling),
          throwsA(
            isA<UnsupportedError>().having(
              (UnsupportedError error) => error.message,
              'message',
              contains(spelling),
            ),
          ),
        );
      }
    }
  });

  test('test_choose_bundled_library_source_property_supports_the_host', () {
    final _ReadSource first = _readSource(
      chooseBundledLibrarySource(Platform.operatingSystem),
    );
    final _ReadSource second = _readSource(
      chooseBundledLibrarySource(Platform.operatingSystem),
    );

    expect(second, first);
  });
}
