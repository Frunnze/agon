import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';

import '../../../bridge/support/wire_name_checks.dart';
import '../../../support/random_inputs.dart';

const String _wireWordSeparator = '_';

final class EnumMappingFromNode<Node extends WireNamed, Model extends Enum> {
  const EnumMappingFromNode({
    required this.functionName,
    required this.seed,
    required this.rustWireNames,
    required this.decodeNode,
    required this.modelValues,
    required this.mapFromNode,
  });

  final String functionName;
  final int seed;
  final List<String> rustWireNames;
  final Node Function(Object? json) decodeNode;
  final List<Model> modelValues;
  final Model Function(Node nodeValue) mapFromNode;
}

final class EnumMappingToNode<Node extends WireNamed, Model extends Enum> {
  const EnumMappingToNode({
    required this.functionName,
    required this.rustWireNames,
    required this.nodeValues,
    required this.modelValues,
    required this.mapToNode,
    required this.mapFromNode,
  });

  final String functionName;
  final List<String> rustWireNames;
  final List<Node> nodeValues;
  final List<Model> modelValues;
  final Node Function(Model modelValue) mapToNode;
  final Model Function(Node nodeValue) mapFromNode;
}

String writeCodeNameOfWireName(String wireName) {
  final List<String> words = wireName.split(_wireWordSeparator);
  final StringBuffer codeName = StringBuffer(words.first);
  for (final String word in words.skip(1)) {
    codeName.write(word.substring(0, 1).toUpperCase());
    codeName.write(word.substring(1));
  }
  return codeName.toString();
}

void testEnumMappingFromNodeProperties<
  Node extends WireNamed,
  Model extends Enum
>(EnumMappingFromNode<Node, Model> mapping) {
  final String prefix = 'test_${mapping.functionName}_property';

  test('${prefix}_maps_each_rust_wire_name_to_its_own_model_value', () {
    final Set<Model> reachedModelValues = <Model>{};
    for (final String wireName in mapping.rustWireNames) {
      final Node nodeValue = mapping.decodeNode(wireName);
      reachedModelValues.add(mapping.mapFromNode(nodeValue));
    }

    expect(reachedModelValues.length, mapping.rustWireNames.length);
    expect(reachedModelValues, mapping.modelValues.toSet());
  });

  test('${prefix}_keeps_the_meaning_of_the_rust_wire_name', () {
    final Random random = seededRandom(mapping.seed);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String wireName = pickOne(random, mapping.rustWireNames);
      final String jsonWireName = jsonDecode(jsonEncode(wireName)) as String;

      final Model modelValue = mapping.mapFromNode(
        mapping.decodeNode(jsonWireName),
      );

      expect(modelValue.name, writeCodeNameOfWireName(wireName));
    }
  });

  test('${prefix}_fails_fast_on_wire_names_rust_never_sends', () {
    final Random random = seededRandom(mapping.seed + 1);
    final Set<String> knownWireNames = mapping.rustWireNames.toSet();
    for (int i = 0; i < propertyIterations; i += 1) {
      final String wireName = pickOne(random, mapping.rustWireNames);
      final List<String> unknownWireNames = <String>[
        for (final String nearMiss in nearMissWireNames(
          random,
          wireName,
          writeCodeNameOfWireName(wireName),
        ))
          if (!knownWireNames.contains(nearMiss)) nearMiss,
      ];
      final String unknownWireName = pickOne(random, unknownWireNames);

      expect(
        () => mapping.mapFromNode(mapping.decodeNode(unknownWireName)),
        throwsFormatException,
        reason: unknownWireName,
      );
    }
  });
}

void testEnumMappingToNodeProperties<
  Node extends WireNamed,
  Model extends Enum
>(EnumMappingToNode<Node, Model> mapping) {
  final String prefix = 'test_${mapping.functionName}_property';

  test('${prefix}_is_undone_by_mapping_back_from_the_node', () {
    for (final Model modelValue in mapping.modelValues) {
      expect(mapping.mapFromNode(mapping.mapToNode(modelValue)), modelValue);
    }
    for (final Node nodeValue in mapping.nodeValues) {
      expect(mapping.mapToNode(mapping.mapFromNode(nodeValue)), nodeValue);
    }
  });

  test('${prefix}_gives_each_model_value_its_own_node_value', () {
    final Set<Node> reachedNodeValues = <Node>{
      for (final Model modelValue in mapping.modelValues)
        mapping.mapToNode(modelValue),
    };

    expect(reachedNodeValues.length, mapping.modelValues.length);
    expect(reachedNodeValues, mapping.nodeValues.toSet());
  });

  test('${prefix}_writes_the_rust_wire_name_of_the_same_meaning', () {
    final Set<String> writtenWireNames = <String>{};
    for (final Model modelValue in mapping.modelValues) {
      final String wireName = mapping.mapToNode(modelValue).wireName;

      expect(writeCodeNameOfWireName(wireName), modelValue.name);
      writtenWireNames.add(wireName);
    }

    expect(writtenWireNames, mapping.rustWireNames.toSet());
  });
}
