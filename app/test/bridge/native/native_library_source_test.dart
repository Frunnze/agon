import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/native/native_library_source.dart';

import '../../support/random_inputs.dart';

const Set<String> _supportedSystems = <String>{
  'android',
  'linux',
  'windows',
  'macos',
  'ios',
};

void main() {
  test('test_choose_bundled_library_source_property_names_each_system', () {
    expect(
      chooseBundledLibrarySource('android'),
      isA<LibraryFile>().having(
        (LibraryFile file) => file.path,
        'path',
        'liborchestration_ffi.so',
      ),
    );
    expect(
      chooseBundledLibrarySource('linux'),
      isA<LibraryFile>().having(
        (LibraryFile file) => file.path,
        'path',
        'liborchestration_ffi.so',
      ),
    );
    expect(
      chooseBundledLibrarySource('windows'),
      isA<LibraryFile>().having(
        (LibraryFile file) => file.path,
        'path',
        'orchestration_ffi.dll',
      ),
    );
    expect(chooseBundledLibrarySource('ios'), isA<LinkedIntoProcess>());
    expect(
      chooseBundledLibrarySource('macos'),
      isA<LinkedIntoProcessOrLibraryFile>().having(
        (LinkedIntoProcessOrLibraryFile file) => file.path,
        'path',
        endsWith('/Frameworks/liborchestration_ffi.dylib'),
      ),
    );
  });

  test('test_choose_bundled_library_source_property_rejects_others', () {
    final Random random = seededRandom(4801);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String operatingSystem = randomText(random);
      if (_supportedSystems.contains(operatingSystem)) {
        continue;
      }

      expect(
        () => chooseBundledLibrarySource(operatingSystem),
        throwsUnsupportedError,
      );
    }
  });
}
