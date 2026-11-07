import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import '../../../support/random_inputs.dart';

typedef ModelFieldValues = List<Object?>;

final class ModelConstructor<Model> {
  const ModelConstructor({
    required this.testNamePrefix,
    required this.seed,
    required this.randomFieldValues,
    required this.construct,
    required this.readFieldValues,
  });

  final String testNamePrefix;
  final int seed;
  final ModelFieldValues Function(Random random) randomFieldValues;
  final Model Function(ModelFieldValues fieldValues) construct;
  final ModelFieldValues Function(Model model) readFieldValues;
}

void testModelConstructorProperties<Model>(ModelConstructor<Model> model) {
  test('${model.testNamePrefix}_keeps_every_field', () {
    final Random random = seededRandom(model.seed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ModelFieldValues givenValues = model.randomFieldValues(random);

      final Model built = model.construct(givenValues);

      expect(model.readFieldValues(built), equals(givenValues));
    }
  });

  test('${model.testNamePrefix}_instances_share_no_state', () {
    final Random random = seededRandom(model.seed + 1);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ModelFieldValues firstValues = model.randomFieldValues(random);
      final Model first = model.construct(firstValues);
      final ModelFieldValues secondValues = model.randomFieldValues(random);

      final Model second = model.construct(secondValues);

      expect(model.readFieldValues(first), equals(firstValues));
      expect(model.readFieldValues(second), equals(secondValues));
    }
  });

  test('${model.testNamePrefix}_rebuilds_from_its_own_fields', () {
    final Random random = seededRandom(model.seed + 2);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Model built = model.construct(model.randomFieldValues(random));
      final ModelFieldValues readValues = model.readFieldValues(built);

      final Model rebuilt = model.construct(readValues);

      expect(model.readFieldValues(rebuilt), equals(readValues));
      expect(model.readFieldValues(built), equals(readValues));
    }
  });
}

final class ModelCopy<Model, Change> {
  const ModelCopy({
    required this.testNamePrefix,
    required this.seed,
    required this.randomModel,
    required this.randomChange,
    required this.applyChange,
    required this.readChangedField,
    required this.readOtherFields,
  });

  final String testNamePrefix;
  final int seed;
  final Model Function(Random random) randomModel;
  final Change Function(Random random) randomChange;
  final Model Function(Model model, Change change) applyChange;
  final Object? Function(Model model) readChangedField;
  final ModelFieldValues Function(Model model) readOtherFields;
}

void testModelCopyProperties<Model, Change>(ModelCopy<Model, Change> copy) {
  test('${copy.testNamePrefix}_sets_the_named_field', () {
    final Random random = seededRandom(copy.seed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Model model = copy.randomModel(random);
      final Change change = copy.randomChange(random);

      final Model changed = copy.applyChange(model, change);

      expect(copy.readChangedField(changed), equals(change));
    }
  });

  test('${copy.testNamePrefix}_keeps_every_other_field', () {
    final Random random = seededRandom(copy.seed + 1);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Model model = copy.randomModel(random);
      final ModelFieldValues otherFieldsBefore = copy.readOtherFields(model);
      final Object? changedFieldBefore = copy.readChangedField(model);

      final Model changed = copy.applyChange(model, copy.randomChange(random));

      expect(copy.readOtherFields(changed), equals(otherFieldsBefore));
      expect(copy.readChangedField(model), equals(changedFieldBefore));
    }
  });

  test('${copy.testNamePrefix}_last_change_wins', () {
    final Random random = seededRandom(copy.seed + 2);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Model model = copy.randomModel(random);
      final Change firstChange = copy.randomChange(random);
      final Change lastChange = copy.randomChange(random);

      final Model changedTwice = copy.applyChange(
        copy.applyChange(model, firstChange),
        lastChange,
      );

      expect(copy.readChangedField(changedTwice), equals(lastChange));
      expect(
        copy.readOtherFields(changedTwice),
        equals(copy.readOtherFields(model)),
      );
    }
  });
}

final class NodeEnumMapping<Choice extends Enum, NodeChoice extends Enum> {
  const NodeEnumMapping({
    required this.testNamePrefix,
    required this.choices,
    required this.nodeChoices,
    required this.mapFromNode,
  });

  final String testNamePrefix;
  final List<Choice> choices;
  final List<NodeChoice> nodeChoices;
  final Choice Function(NodeChoice nodeChoice) mapFromNode;
}

void testNodeEnumMappingProperties<
  Choice extends Enum,
  NodeChoice extends Enum
>(NodeEnumMapping<Choice, NodeChoice> mapping) {
  test('${mapping.testNamePrefix}_each_node_value_has_its_own', () {
    final Set<Choice> mappedChoices = <Choice>{};

    for (final NodeChoice nodeChoice in mapping.nodeChoices) {
      mappedChoices.add(mapping.mapFromNode(nodeChoice));
    }

    expect(mappedChoices, hasLength(mapping.nodeChoices.length));
  });

  test('${mapping.testNamePrefix}_every_value_is_reached', () {
    final Set<Choice> mappedChoices = <Choice>{};

    for (final NodeChoice nodeChoice in mapping.nodeChoices) {
      mappedChoices.add(mapping.mapFromNode(nodeChoice));
    }

    expect(mappedChoices, unorderedEquals(mapping.choices));
  });

  test('${mapping.testNamePrefix}_keeps_the_node_name', () {
    for (final NodeChoice nodeChoice in mapping.nodeChoices) {
      final Choice mappedChoice = mapping.mapFromNode(nodeChoice);

      expect(mappedChoice.name, nodeChoice.name);
      expect(mapping.mapFromNode(nodeChoice), same(mappedChoice));
    }
  });
}

void
testNodeEnumRoundTripProperty<Choice extends Enum, NodeChoice extends Enum>(
  NodeEnumMapping<Choice, NodeChoice> mapping,
  NodeChoice Function(Choice choice) mapToNode,
) {
  test('${mapping.testNamePrefix}_round_trip_through_the_node', () {
    for (final Choice choice in mapping.choices) {
      expect(mapping.mapFromNode(mapToNode(choice)), same(choice));
    }
    for (final NodeChoice nodeChoice in mapping.nodeChoices) {
      expect(mapToNode(mapping.mapFromNode(nodeChoice)), same(nodeChoice));
    }
  });
}

void testEnumLabelProperties<Choice extends Enum>({
  required String testNamePrefix,
  required List<Choice> choices,
  required String Function(Choice choice) readLabel,
}) {
  test('${testNamePrefix}_is_unique', () {
    final Set<String> labels = <String>{};

    for (final Choice choice in choices) {
      labels.add(readLabel(choice).toLowerCase());
    }

    expect(labels, hasLength(choices.length));
  });

  test('${testNamePrefix}_is_trimmed_single_line_text', () {
    for (final Choice choice in choices) {
      final String label = readLabel(choice);

      expect(label, isNotEmpty);
      expect(label, label.trim());
      expect(label, isNot(contains('\n')));
      expect(label, isNot(contains('  ')));
    }
  });

  test('${testNamePrefix}_starts_with_a_capital_letter', () {
    for (final Choice choice in choices) {
      final String firstLetter = readLabel(choice).substring(0, 1);

      expect(firstLetter, firstLetter.toUpperCase());
      expect(firstLetter, isNot(firstLetter.toLowerCase()));
    }
  });
}
