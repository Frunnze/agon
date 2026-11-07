import 'dart:ffi';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/native/native_library_opening.dart';
import 'package:agent_orchestration/bridge/native/native_library_source.dart';
import 'package:agent_orchestration/bridge/native/node_entry_point.dart';

import '../../support/random_inputs.dart';
import '../support/hostile_texts.dart';
import 'support/bundled_node_library.dart';

const int _firstSeed = 6268000;
const String _missingFolder = 'build/no_such_native_library_folder';
const String _processSymbol = 'malloc';

final String _commandSymbol = NodeEntryPoint.handleCommand.symbol;

List<String> _everyNodeSymbol() {
  final List<String> symbols = <String>[stopSymbol, freeStringSymbol];
  for (final NodeEntryPoint entryPoint in NodeEntryPoint.values) {
    symbols.add(entryPoint.symbol);
  }
  return symbols;
}

String _randomMissingLibraryPath(Random random) {
  final String fileName = randomHostileText(random).replaceAll('/', '_');
  return '$_missingFolder/$fileName.dylib';
}

void _expectEveryNodeSymbol(DynamicLibrary library) {
  for (final String symbol in _everyNodeSymbol()) {
    expect(library.providesSymbol(symbol), isTrue, reason: symbol);
  }
}

bool _processProvidesTheNode() {
  return DynamicLibrary.process().providesSymbol(_commandSymbol);
}

void main() {
  final String? skipReason = readBundledLibrarySkipReason();

  test('test_open_native_library_property_file_exports_every_symbol', () {
    _expectEveryNodeSymbol(openNativeLibrary(bundledLibraryFile()));
  }, skip: skipReason);

  test('test_open_native_library_property_same_file_same_library', () {
    final DynamicLibrary first = openNativeLibrary(bundledLibraryFile());
    final DynamicLibrary second = openNativeLibrary(bundledLibraryFile());

    expect(second.handle, first.handle);
  }, skip: skipReason);

  test('test_open_native_library_property_missing_files_raise_errors', () {
    final Random random = seededRandom(_firstSeed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String path = _randomMissingLibraryPath(random);

      expect(
        () => openNativeLibrary(LibraryFile(path: path)),
        throwsArgumentError,
        reason: path,
      );
    }
  });

  test('test_open_native_library_property_linked_is_the_process', () {
    final Random random = seededRandom(_firstSeed + 1);
    final DynamicLibrary process = DynamicLibrary.process();
    final DynamicLibrary opened = openNativeLibrary(const LinkedIntoProcess());

    expect(opened.handle, process.handle);
    expect(opened.providesSymbol(_processSymbol), isTrue);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String symbol = randomHostileText(random);

      expect(opened.providesSymbol(symbol), process.providesSymbol(symbol));
    }
  });

  test('test_open_process_or_file_property_uses_the_process_node_first', () {
    final Random random = seededRandom(_firstSeed + 2);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NativeLibrarySource source = LinkedIntoProcessOrLibraryFile(
        path: _randomMissingLibraryPath(random),
      );

      if (_processProvidesTheNode()) {
        expect(
          openNativeLibrary(source).handle,
          DynamicLibrary.process().handle,
        );
        continue;
      }
      expect(() => openNativeLibrary(source), throwsArgumentError);
    }
  });

  test('test_open_process_or_file_property_always_reaches_the_node', () {
    final NativeLibrarySource source = LinkedIntoProcessOrLibraryFile(
      path: bundledLibraryPath(),
    );

    _expectEveryNodeSymbol(openNativeLibrary(source));
    _expectEveryNodeSymbol(openNativeLibrary(source));
  }, skip: skipReason);

  test('test_open_process_or_file_property_is_the_process_or_the_file', () {
    final NativeLibrarySource source = LinkedIntoProcessOrLibraryFile(
      path: bundledLibraryPath(),
    );
    final bool processHadTheNode = _processProvidesTheNode();
    final DynamicLibrary opened = openNativeLibrary(source);
    final DynamicLibrary file = openNativeLibrary(bundledLibraryFile());
    final DynamicLibrary process = DynamicLibrary.process();

    final Pointer<Void> expectedHandle = processHadTheNode
        ? process.handle
        : file.handle;
    expect(opened.handle, expectedHandle);
  }, skip: skipReason);
}
