import 'dart:ffi';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/native/native_library_opening.dart';
import 'package:agent_orchestration/bridge/native/node_entry_point.dart';

import '../../support/random_inputs.dart';
import '../support/hostile_texts.dart';
import 'support/bundled_node_library.dart';

const String _symbolPrefix = 'orchestration_';
const int _hostileSymbolSeed = 6266001;
final RegExp _cIdentifierInSnakeCase = RegExp(r'^[a-z]+(_[a-z]+)*$');
final RegExp _upperCaseLetter = RegExp('[A-Z]');

const Map<NodeEntryPoint, String> _rustExportedEntryPoints =
    <NodeEntryPoint, String>{
      NodeEntryPoint.start: 'orchestration_start',
      NodeEntryPoint.handleCommand: 'orchestration_handle_command',
    };

List<String> _everyNodeSymbol() {
  final List<String> symbols = <String>[stopSymbol, freeStringSymbol];
  for (final NodeEntryPoint entryPoint in NodeEntryPoint.values) {
    symbols.add(entryPoint.symbol);
  }
  return symbols;
}

String _snakeCaseOf(String camelCaseName) {
  return camelCaseName.replaceAllMapped(
    _upperCaseLetter,
    (Match letter) => '_${letter[0]!.toLowerCase()}',
  );
}

void _expectNodeSymbolShape(String symbol) {
  expect(symbol, startsWith(_symbolPrefix));
  expect(_cIdentifierInSnakeCase.hasMatch(symbol), isTrue, reason: symbol);
}

void main() {
  final String? skipReason = readBundledLibrarySkipReason();

  test('test_node_entry_point_constructor_property_symbol_follows_name', () {
    for (final NodeEntryPoint entryPoint in NodeEntryPoint.values) {
      final String expectedSymbol =
          '$_symbolPrefix${_snakeCaseOf(entryPoint.name)}';

      expect(entryPoint.symbol, expectedSymbol);
      expect(NodeEntryPoint.values.byName(entryPoint.name), entryPoint);
    }
  });

  test('test_node_entry_point_constructor_property_symbols_are_unique', () {
    final List<String> symbols = _everyNodeSymbol();

    expect(symbols.toSet(), hasLength(symbols.length));
    for (final String symbol in symbols) {
      _expectNodeSymbolShape(symbol);
    }
  });

  test('test_node_entry_point_constructor_property_matches_rust_exports', () {
    expect(NodeEntryPoint.values.toSet(), _rustExportedEntryPoints.keys);
    for (final NodeEntryPoint entryPoint in NodeEntryPoint.values) {
      expect(entryPoint.symbol, _rustExportedEntryPoints[entryPoint]);
    }
  });

  test('test_node_entry_point_symbol_property_is_exported_by_the_node', () {
    final DynamicLibrary library = openNativeLibrary(bundledLibraryFile());

    for (final NodeEntryPoint entryPoint in NodeEntryPoint.values) {
      expect(library.providesSymbol(entryPoint.symbol), isTrue);
    }
  }, skip: skipReason);

  test('test_node_entry_point_symbol_property_others_are_not_exported', () {
    final Random random = seededRandom(_hostileSymbolSeed);
    final DynamicLibrary library = openNativeLibrary(bundledLibraryFile());
    final List<String> symbols = _everyNodeSymbol();

    for (int i = 0; i < propertyIterations; i += 1) {
      final String strangerSymbol =
          '$_symbolPrefix${randomHostileText(random)}';
      if (symbols.contains(strangerSymbol)) {
        continue;
      }

      expect(library.providesSymbol(strangerSymbol), isFalse);
    }
  }, skip: skipReason);

  test('test_node_entry_point_symbol_property_is_stable_and_distinct', () {
    final Set<String> seenSymbols = <String>{};
    for (final NodeEntryPoint entryPoint in NodeEntryPoint.values) {
      expect(
        entryPoint.symbol,
        NodeEntryPoint.values[entryPoint.index].symbol,
      );
      expect(seenSymbols.add(entryPoint.symbol), isTrue);
      _expectNodeSymbolShape(entryPoint.symbol);
    }
  });

  test('test_stop_symbol_property_is_exported_by_the_node', () {
    final DynamicLibrary library = openNativeLibrary(bundledLibraryFile());

    expect(library.providesSymbol(stopSymbol), isTrue);
  }, skip: skipReason);

  test('test_stop_symbol_property_is_not_an_entry_point_symbol', () {
    for (final NodeEntryPoint entryPoint in NodeEntryPoint.values) {
      expect(stopSymbol, isNot(entryPoint.symbol));
    }
    expect(stopSymbol, isNot(freeStringSymbol));
  });

  test('test_stop_symbol_property_names_the_rust_stop_export', () {
    _expectNodeSymbolShape(stopSymbol);
    expect(stopSymbol, '${_symbolPrefix}stop');
  });

  test('test_free_string_symbol_property_is_exported_by_the_node', () {
    final DynamicLibrary library = openNativeLibrary(bundledLibraryFile());

    expect(library.providesSymbol(freeStringSymbol), isTrue);
  }, skip: skipReason);

  test('test_free_string_symbol_property_is_not_an_entry_point_symbol', () {
    for (final NodeEntryPoint entryPoint in NodeEntryPoint.values) {
      expect(freeStringSymbol, isNot(entryPoint.symbol));
    }
  });

  test('test_free_string_symbol_property_names_the_rust_free_export', () {
    _expectNodeSymbolShape(freeStringSymbol);
    expect(freeStringSymbol, '${_symbolPrefix}free_string');
  });
}
