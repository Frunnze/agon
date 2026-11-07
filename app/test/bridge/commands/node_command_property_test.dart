import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';

import '../../support/random_inputs.dart';
import '../codecs/support/codec_rows.dart';
import '../support/all_command_shapes.dart';
import '../support/arbitrary_json.dart';
import '../support/command_shape.dart';
import '../support/hostile_texts.dart';
import '../support/simple_command_properties.dart';
import '../support/wire_contract_checks.dart';

const int _firstSeed = 8640000;
const int _largestArgumentCount = 6;
const String _rustCommandTag = 'command';
const String _strayField = 'stray';
const String _emptyObjectText = '{}';
final RegExp _snakeCaseName = RegExp(r'^[a-z]+(_[a-z]+)*$');

final class _ScriptedCommand implements NodeCommand<Object?> {
  const _ScriptedCommand({required this.name, required this.arguments});

  @override
  final String name;

  @override
  final JsonObject arguments;

  @override
  Object? decodeReply(Object? okValue) => okValue;
}

JsonObject _randomArguments(Random random) {
  final JsonObject arguments = <String, Object?>{};
  final int argumentCount = random.nextInt(_largestArgumentCount);
  for (int i = 0; i < argumentCount; i += 1) {
    final String field = randomHostileText(random);
    if (field != commandNameField) {
      arguments[field] = randomArbitraryJson(random);
    }
  }
  return arguments;
}

_ScriptedCommand _randomScriptedCommand(Random random) {
  return _ScriptedCommand(
    name: randomArgumentText(random),
    arguments: _randomArguments(random),
  );
}

void main() {
  _testEncodeNodeCommandProperties();
  _testCommandNameFieldProperties();
  _testNoArgumentsProperties();
}

void _testEncodeNodeCommandProperties() {
  test('test_encode_node_command_property_is_the_name_then_the_arguments', () {
    final Random random = seededRandom(_firstSeed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _ScriptedCommand command = _randomScriptedCommand(random);
      final JsonObject wireCommand = encodeNodeCommand(command);
      final JsonObject wireArguments = withoutField(
        wireCommand,
        commandNameField,
      );

      expect(wireCommand.keys.first, commandNameField);
      expect(wireCommand[commandNameField], command.name);
      expect(wireArguments, equals(command.arguments));
      expect(wireCommand, hasLength(command.arguments.length + 1));
    }
  });

  test('test_encode_node_command_property_leaves_the_arguments_alone', () {
    final Random random = seededRandom(_firstSeed + 1);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _ScriptedCommand command = _randomScriptedCommand(random);
      final String argumentsText = jsonEncode(command.arguments);
      final JsonObject wireCommand = encodeNodeCommand(command);

      wireCommand[_strayField] = randomText(random);
      wireCommand.remove(commandNameField);

      expect(jsonEncode(command.arguments), argumentsText);
      expect(
        encodeNodeCommand(command),
        containsPair(commandNameField, command.name),
      );
    }
  });

  test('test_encode_node_command_property_every_command_survives_json', () {
    final Random random = seededRandom(_firstSeed + 2);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CommandShape shape = pickOne(random, allCommandShapes);
      final NodeCommand<Object?> command = shape.buildCommand(random);
      final JsonObject wireCommand = encodeNodeCommand(command);
      final JsonObject scriptedWireCommand = encodeNodeCommand(
        _randomScriptedCommand(random),
      );

      expect(rereadThroughWire(wireCommand), equals(wireCommand));
      expect(wireCommand[commandNameField], shape.commandName);
      expect(
        rereadThroughWire(scriptedWireCommand),
        equals(scriptedWireCommand),
      );
    }
  });

  test(
    'test_encode_node_command_property_rejects_an_argument_named_command',
    () {
      final Random random = seededRandom(_firstSeed + 3);

      for (int i = 0; i < propertyIterations; i += 1) {
        final JsonObject arguments = _randomArguments(random);
        arguments[commandNameField] = randomArgumentText(random);
        final _ScriptedCommand command = _ScriptedCommand(
          name: pickOne(random, nodeCommandNames),
          arguments: arguments,
        );

        expect(() => encodeNodeCommand(command), throwsArgumentError);
      }
    },
  );
}

void _testCommandNameFieldProperties() {
  test('test_command_name_field_property_is_the_rust_command_tag', () {
    final Random random = seededRandom(_firstSeed + 10);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CommandShape shape = pickOne(random, allCommandShapes);
      final Object? wireCommand = rereadThroughWire(
        encodeNodeCommand(shape.buildCommand(random)),
      );

      expect(commandNameField, _rustCommandTag);
      expect(wireCommand, containsPair(_rustCommandTag, shape.commandName));
    }
  });

  test('test_command_name_field_property_never_names_an_argument', () {
    final Random random = seededRandom(_firstSeed + 11);

    for (final CommandShape shape in allCommandShapes) {
      final NodeCommand<Object?> command = shape.buildCommand(random);

      expect(shape.argumentFields, isNot(contains(commandNameField)));
      expect(command.arguments.keys, isNot(contains(commandNameField)));
    }
  });

  test(
    'test_command_name_field_property_is_snake_case_and_names_no_command',
    () {
      final Random random = seededRandom(_firstSeed + 12);

      for (int i = 0; i < propertyIterations; i += 1) {
        final String commandName = pickOne(random, nodeCommandNames);

        expect(_snakeCaseName.hasMatch(commandNameField), isTrue);
        expect(commandName, isNot(commandNameField));
      }
    },
  );
}

void _testNoArgumentsProperties() {
  test('test_no_arguments_property_is_an_empty_json_object', () {
    final Random random = seededRandom(_firstSeed + 20);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String field = randomHostileText(random);

      expect(noArguments, isEmpty);
      expect(noArguments.containsKey(field), isFalse);
      expect(jsonEncode(noArguments), _emptyObjectText);
      expect(rereadThroughWire(noArguments), equals(noArguments));
    }
  });

  test('test_no_arguments_property_cannot_be_changed', () {
    final Random random = seededRandom(_firstSeed + 21);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String field = randomHostileText(random);
      final Object? fieldValue = randomArbitraryJson(random);

      expect(() => noArguments[field] = fieldValue, throwsUnsupportedError);
      expect(noArguments.clear, throwsUnsupportedError);
      expect(noArguments, isEmpty);
    }
  });

  test('test_no_arguments_property_encodes_to_only_the_name', () {
    final Random random = seededRandom(_firstSeed + 22);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _ScriptedCommand command = _ScriptedCommand(
        name: randomArgumentText(random),
        arguments: noArguments,
      );
      final JsonObject wireCommand = encodeNodeCommand(command);

      expect(
        wireCommand,
        equals(<String, Object?>{commandNameField: command.name}),
      );
      wireCommand[_strayField] = randomText(random);
      expect(noArguments, isEmpty);
    }
  });
}
