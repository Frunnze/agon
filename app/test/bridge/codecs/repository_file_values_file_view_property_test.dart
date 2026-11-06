import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/repository_file_values.dart';

import '../../support/random_inputs.dart';
import '../support/random_file_json.dart';
import '../support/random_wire_values.dart';
import '../support/wire_contract_checks.dart';

const WireFields _repositoryFileFields = WireFields(
  requiredFields: <String>['path', 'size', 'preview'],
  optionalFields: <String>[],
  defaultedListFields: <String>[],
);

RepositoryFileView _randomRepositoryFile(Random random) {
  return RepositoryFileView(
    path: randomText(random),
    size: randomWholeNumber(random),
    preview: FilePreview.fromJson(randomFilePreviewJson(random)),
  );
}

void main() {
  test(
    'test_repository_file_view_from_json_property_missing_fields_follow_node',
    () {
      final Random random = seededRandom(52701);

      for (int i = 0; i < propertyIterations; i += 1) {
        expectRequiredFieldsAreNeeded(
          randomRepositoryFileJson(random),
          _repositoryFileFields,
          RepositoryFileView.fromJson,
        );
      }
    },
  );

  test(
    'test_repository_file_view_from_json_property_wrong_kinds_raise_format',
    () {
      final Random random = seededRandom(52702);

      for (int i = 0; i < propertyIterations; i += 1) {
        expectWrongKindValuesAreRejected(
          random,
          randomRepositoryFileJson(random),
          RepositoryFileView.fromJson,
        );
      }
    },
  );

  test(
    'test_repository_file_view_from_json_property_reads_each_field_by_name',
    () {
      final Random random = seededRandom(52703);

      for (int i = 0; i < propertyIterations; i += 1) {
        final JsonObject json = randomRepositoryFileJson(random);

        final RepositoryFileView file = RepositoryFileView.fromJson(
          withUnknownFields(random, json),
        );

        expect(file.path, json['path']);
        expect(file.size, json['size']);
        expect(file.preview.toJson(), equals(json['preview']));
      }
    },
  );

  test(
    'test_repository_file_view_to_json_property_writes_exactly_node_fields',
    () {
      final Random random = seededRandom(52704);

      for (int i = 0; i < propertyIterations; i += 1) {
        final JsonObject encoded = _randomRepositoryFile(random).toJson();

        expect(encoded.keys.toSet(), equals(_repositoryFileFields.everyField));
      }
    },
  );

  test(
    'test_repository_file_view_to_json_property_values_mirror_the_file',
    () {
      final Random random = seededRandom(52705);

      for (int i = 0; i < propertyIterations; i += 1) {
        final RepositoryFileView file = _randomRepositoryFile(random);

        final JsonObject encoded = file.toJson();

        expect(encoded['path'], file.path);
        expect(encoded['size'], file.size);
        expect(encoded['preview'], equals(file.preview.toJson()));
      }
    },
  );

  test(
    'test_repository_file_view_to_json_property_plain_json_decodes_back',
    () {
      final Random random = seededRandom(52706);

      for (int i = 0; i < propertyIterations; i += 1) {
        expectPlainJsonThatDecodesBack(
          _randomRepositoryFile(random),
          RepositoryFileView.fromJson,
        );
      }
    },
  );
}
