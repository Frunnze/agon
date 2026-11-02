import 'dart:math';

import '../../support/random_inputs.dart';
import 'node_json_primitives.dart';
import 'node_wire_names.dart';

const int _deepestNesting = 3;
const int _largestMagnitude = 1 << 31;
const int _keepStructureOdds = 4;

const List<String> _familiarWords = <String>[
  'id',
  'name',
  'kind',
  'state',
  'topic',
  'every',
  'command',
  'ok',
  'error',
  'device',
  'workspaces',
  'projects',
  'task',
  'run',
  'workflow',
  'scope',
  'at',
  'on',
  'hour',
  'minute',
  'all_workspaces',
  'only_workspaces',
  'any_free_runner',
  'one_agent',
  'approved',
  'waiting',
];

enum _ArbitraryJsonKind { nothing, flag, whole, fraction, text, word }

enum _NestedJsonKind { list, object }

enum _FieldMutation { remove, replace, descend }

Object? randomArbitraryJson(Random random) {
  return _randomJsonAtDepth(random, 0);
}

Object? mutateJson(Random random, Object? json) {
  final bool keepsStructure = random.nextInt(_keepStructureOdds) != 0;
  if (json is Map<String, Object?> && json.isNotEmpty && keepsStructure) {
    return _mutateObject(random, json);
  }
  if (json is List<Object?> && json.isNotEmpty && keepsStructure) {
    final List<Object?> mutated = List<Object?>.of(json);
    final int index = random.nextInt(json.length);
    mutated[index] = mutateJson(random, json[index]);
    return mutated;
  }
  return randomArbitraryJson(random);
}

Map<String, Object?> _mutateObject(Random random, Map<String, Object?> json) {
  final Map<String, Object?> mutated = Map<String, Object?>.of(json);
  final String field = pickOne(random, json.keys.toList());
  switch (pickOne(random, _FieldMutation.values)) {
    case _FieldMutation.remove:
      mutated.remove(field);
    case _FieldMutation.replace:
      mutated[field] = randomArbitraryJson(random);
    case _FieldMutation.descend:
      mutated[field] = mutateJson(random, json[field]);
  }
  return mutated;
}

Object? _randomJsonAtDepth(Random random, int depth) {
  final bool mayNest = depth < _deepestNesting;
  if (mayNest && random.nextBool()) {
    return _randomNestedJson(random, depth + 1);
  }
  return switch (pickOne(random, _ArbitraryJsonKind.values)) {
    _ArbitraryJsonKind.nothing => null,
    _ArbitraryJsonKind.flag => random.nextBool(),
    _ArbitraryJsonKind.whole =>
      random.nextInt(_largestMagnitude) - _largestMagnitude ~/ 2,
    _ArbitraryJsonKind.fraction => random.nextDouble(),
    _ArbitraryJsonKind.text => randomText(random),
    _ArbitraryJsonKind.word => _randomFamiliarWord(random),
  };
}

Object? _randomNestedJson(Random random, int depth) {
  final int count = random.nextInt(_keepStructureOdds);
  switch (pickOne(random, _NestedJsonKind.values)) {
    case _NestedJsonKind.list:
      final List<Object?> elements = <Object?>[];
      for (int i = 0; i < count; i += 1) {
        elements.add(_randomJsonAtDepth(random, depth));
      }
      return elements;
    case _NestedJsonKind.object:
      final Map<String, Object?> fields = <String, Object?>{};
      for (int i = 0; i < count; i += 1) {
        fields[_randomFamiliarWord(random)] = _randomJsonAtDepth(
          random,
          depth,
        );
      }
      return fields;
  }
}

String _randomFamiliarWord(Random random) {
  final List<String> words = <String>[
    ..._familiarWords,
    ...nodeTaskStatuses,
    ...nodeDiffChanges,
    randomMomentText(random),
    randomUuidText(random),
  ];
  return pickOne(random, words);
}
