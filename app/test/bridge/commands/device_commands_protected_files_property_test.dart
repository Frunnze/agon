import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/commands/device_commands.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../support/random_inputs.dart';
import '../support/device_command_checks.dart';
import '../support/hostile_texts.dart';

enum _PatternEdit { append, remove, replace, clear, reverse }

const String _workspaceIdField = 'workspace_id';
const String _patternsField = 'patterns';
const int _largestEditCount = 6;

List<String> _randomPatternsWithRepeats(Random random) {
  final List<String> patterns = randomHostileTexts(random);
  if (patterns.isNotEmpty && random.nextBool()) {
    patterns.add(pickOne(random, patterns));
  }
  return patterns;
}

List<String> _randomlyShapedCopy(Random random, List<String> patterns) {
  final List<List<String>> shapes = <List<String>>[
    List<String>.of(patterns),
    List<String>.of(patterns, growable: false),
    List<String>.unmodifiable(patterns),
  ];
  return pickOne(random, shapes);
}

void _applyRandomEdit(Random random, List<String> patterns) {
  final _PatternEdit edit = pickOne(random, _PatternEdit.values);
  switch (edit) {
    case _PatternEdit.append:
      patterns.add(randomHostileText(random));
    case _PatternEdit.remove:
      if (patterns.isNotEmpty) {
        patterns.removeAt(random.nextInt(patterns.length));
      }
    case _PatternEdit.replace:
      if (patterns.isNotEmpty) {
        patterns[random.nextInt(patterns.length)] = randomText(random);
      }
    case _PatternEdit.clear:
      patterns.clear();
    case _PatternEdit.reverse:
      final List<String> reversed = patterns.reversed.toList();
      patterns.setAll(0, reversed);
  }
}

SetProtectedFilesCommand _randomCommand(Random random) {
  return SetProtectedFilesCommand(
    workspaceId: WorkspaceId(randomHostileText(random)),
    patterns: _randomPatternsWithRepeats(random),
  );
}

void main() {
  test('test_set_protected_files_command_constructor_property_keeps_order'
      '_and_repeats', () {
    final Random random = seededRandom(56601);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> patterns = _randomPatternsWithRepeats(random);

      final SetProtectedFilesCommand command = SetProtectedFilesCommand(
        workspaceId: WorkspaceId(randomHostileText(random)),
        patterns: _randomlyShapedCopy(random, patterns),
      );

      expect(command.patterns, orderedEquals(patterns));
      expect(
        () => command.patterns.add(randomText(random)),
        throwsUnsupportedError,
      );
    }
  });

  test('test_set_protected_files_command_constructor_property_ignores'
      '_later_edits', () {
    final Random random = seededRandom(56602);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> patterns = _randomPatternsWithRepeats(random);
      final List<String> patternsBefore = List<String>.of(patterns);
      final SetProtectedFilesCommand command = SetProtectedFilesCommand(
        workspaceId: WorkspaceId(randomHostileText(random)),
        patterns: patterns,
      );

      final int editCount = 1 + random.nextInt(_largestEditCount);
      for (int edit = 0; edit < editCount; edit += 1) {
        _applyRandomEdit(random, patterns);
      }

      expect(command.patterns, orderedEquals(patternsBefore));
      expect(command.arguments[_patternsField], orderedEquals(patternsBefore));
    }
  });

  test('test_set_protected_files_command_arguments_property_sends_exactly'
      '_workspace_and_patterns', () {
    final Random random = seededRandom(56611);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkspaceId workspaceId = WorkspaceId(randomHostileText(random));
      final List<String> patterns = _randomPatternsWithRepeats(random);

      final JsonObject arguments = SetProtectedFilesCommand(
        workspaceId: workspaceId,
        patterns: patterns,
      ).arguments;

      expect(arguments.keys.toSet(), <String>{
        _workspaceIdField,
        _patternsField,
      });
      expect(arguments[_workspaceIdField], workspaceId.value);
      expect(arguments[_patternsField], orderedEquals(patterns));
    }
  });

  test('test_set_protected_files_command_arguments_property_survives_json'
      '_text', () {
    final Random random = seededRandom(56612);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SetProtectedFilesCommand command = _randomCommand(random);

      final JsonObject reread = rereadCommandThroughText(command);

      expect(reread, equals(encodeNodeCommand(command)));
      expect(reread[_patternsField], orderedEquals(command.patterns));
    }
  });

  test('test_set_protected_files_command_arguments_property_cannot_change'
      '_the_command', () {
    final Random random = seededRandom(56613);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SetProtectedFilesCommand command = _randomCommand(random);
      final JsonObject argumentsBefore = encodeNodeCommand(command);

      final JsonObject arguments = command.arguments;
      final List<Object?> sentPatterns =
          arguments[_patternsField]! as List<Object?>;
      final String extraPattern = randomHostileText(random);

      expect(() => sentPatterns.add(extraPattern), throwsUnsupportedError);
      expect(sentPatterns.clear, throwsUnsupportedError);
      expect(encodeNodeCommand(command), equals(argumentsBefore));
    }
  });
}
