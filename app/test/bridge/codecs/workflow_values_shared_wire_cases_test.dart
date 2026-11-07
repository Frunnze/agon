import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/workflow_values.dart';
import 'package:agent_orchestration/bridge/codecs/workflow_views.dart';

const String _sharedWireCasesPath =
    '../rust/crates/orchestration-core/tests/fixtures/'
    'workflow_wire_cases.json';

Map<String, Object?> _readSharedWireCases() {
  final String sharedText = File(_sharedWireCasesPath).readAsStringSync();
  final Object? cases = jsonDecode(sharedText);
  if (cases is! Map<String, Object?>) {
    throw const FormatException('the shared wire cases are not an object');
  }
  return cases;
}

List<String> _readNames(Map<String, Object?> cases, String listName) {
  final Object? names = cases[listName];
  if (names is! List<Object?>) {
    throw FormatException('the shared wire cases have no list $listName');
  }
  return <String>[for (final Object? name in names) name! as String];
}

List<String> _listWireNames(List<WireNamed> values) {
  return <String>[for (final WireNamed value in values) value.wireName];
}

void main() {
  final Map<String, Object?> cases = _readSharedWireCases();

  test('test_agent_kind_wire_name_property_matches_the_shared_table', () {
    final List<String> names = _readNames(cases, 'agent_kinds');

    expect(_listWireNames(AgentKind.values), names);
    for (final String name in names) {
      expect(AgentKind.decode(name).wireName, name);
    }
  });

  test('test_step_kind_wire_name_property_matches_the_shared_table', () {
    final List<String> names = _readNames(cases, 'step_kinds');

    expect(_listWireNames(StepKind.values), names);
    for (final String name in names) {
      expect(StepKind.decode(name).wireName, name);
    }
  });

  test('test_signature_state_wire_name_property_matches_shared_table', () {
    final List<String> names = _readNames(cases, 'signature_states');

    expect(_listWireNames(SignatureState.values), names);
    for (final String name in names) {
      expect(SignatureState.decode(name).wireName, name);
    }
  });

  test('test_workflow_from_json_property_reads_the_shared_workflow_back', () {
    final Object? sharedWorkflow = cases['workflow'];

    final Workflow workflow = Workflow.fromJson(sharedWorkflow);

    expect(jsonDecode(jsonEncode(workflow.toJson())), sharedWorkflow);
  });
}
