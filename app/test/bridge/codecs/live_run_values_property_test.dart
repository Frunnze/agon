import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/live_run_values.dart';

import '../../support/random_inputs.dart';
import '../support/random_live_json.dart';

const String _kindField = 'kind';

typedef _RunEventTypeCheck = bool Function(RunEvent event);

final class _RunEventFamily {
  const _RunEventFamily(this.typeName, this.kind, this.isOfType, this.fields);

  final String typeName;
  final String kind;
  final _RunEventTypeCheck isOfType;
  final Set<String> fields;
}

bool _isStepStatusChanged(RunEvent event) => event is StepStatusChanged;

bool _isLogAppended(RunEvent event) => event is LogAppended;

bool _isChatAppended(RunEvent event) => event is ChatAppended;

bool _isSessionStarted(RunEvent event) => event is SessionStarted;

bool _isWorktreeCreated(RunEvent event) => event is WorktreeCreated;

bool _isLinkChanged(RunEvent event) => event is LinkChanged;

bool _isRunFailed(RunEvent event) => event is RunFailed;

bool _isStepResultRecorded(RunEvent event) => event is StepResultRecorded;

bool _isRunFinished(RunEvent event) => event is RunFinished;

const List<_RunEventFamily> _families = <_RunEventFamily>[
  _RunEventFamily(
    'step_status_changed',
    'step_status_changed',
    _isStepStatusChanged,
    <String>{_kindField, 'step_name', 'status'},
  ),
  _RunEventFamily('log_appended', 'log_appended', _isLogAppended, <String>{
    _kindField,
    'line',
  }),
  _RunEventFamily('chat_appended', 'chat_appended', _isChatAppended, <String>{
    _kindField,
    'message',
  }),
  _RunEventFamily(
    'session_started',
    'session_started',
    _isSessionStarted,
    <String>{_kindField, 'session'},
  ),
  _RunEventFamily(
    'worktree_created',
    'worktree_created',
    _isWorktreeCreated,
    <String>{_kindField, 'branch'},
  ),
  _RunEventFamily('link_changed', 'link_changed', _isLinkChanged, <String>{
    _kindField,
    'link',
  }),
  _RunEventFamily('run_failed', 'failed', _isRunFailed, <String>{
    _kindField,
    'failure',
  }),
  _RunEventFamily(
    'step_result_recorded',
    'step_result_recorded',
    _isStepResultRecorded,
    <String>{_kindField, 'step_name', 'result', 'outcome'},
  ),
  _RunEventFamily('run_finished', 'finished', _isRunFinished, <String>{
    _kindField,
  }),
];

Object? _throughJsonText(Object? json) => jsonDecode(jsonEncode(json));

RunEvent _randomEventOfKind(Random random, String kind) {
  JsonObject eventJson = randomRunEventJson(random);
  while (eventJson[_kindField] != kind) {
    eventJson = randomRunEventJson(random);
  }
  return RunEvent.fromJson(eventJson);
}

void _testEventFamily(_RunEventFamily family, int seed) {
  test('test_${family.typeName}_to_json_property_writes_kind_and_fields', () {
    final Random random = seededRandom(seed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RunEvent event = _randomEventOfKind(random, family.kind);

      final JsonObject encoded = decodeObject(event.toJson());

      expect(encoded[_kindField], family.kind);
      expect(encoded.keys.toSet(), equals(family.fields));
    }
  });

  test('test_${family.typeName}_to_json_property_round_trips_its_type', () {
    final Random random = seededRandom(seed + 1);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RunEvent event = _randomEventOfKind(random, family.kind);
      final Object? encoded = _throughJsonText(event.toJson());

      final RunEvent decoded = RunEvent.fromJson(encoded);

      expect(family.isOfType(decoded), isTrue);
      expect(_throughJsonText(decoded.toJson()), equals(encoded));
    }
  });

  test('test_${family.typeName}_to_json_property_survives_json_text', () {
    final Random random = seededRandom(seed + 2);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RunEvent event = _randomEventOfKind(random, family.kind);

      final JsonObject encoded = decodeObject(event.toJson());

      expect(_throughJsonText(encoded), equals(encoded));
    }
  });
}

void main() {
  for (int index = 0; index < _families.length; index += 1) {
    _testEventFamily(_families[index], 5300 + 10 * index);
  }

  test('test_run_event_from_json_property_each_kind_decodes_to_its_type', () {
    final Random random = seededRandom(5391);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject eventJson = randomRunEventJson(random);

      final RunEvent event = RunEvent.fromJson(eventJson);

      int matchingFamilies = 0;
      for (final _RunEventFamily family in _families) {
        final bool isNamedKind = family.kind == eventJson[_kindField];
        expect(family.isOfType(event), isNamedKind);
        if (isNamedKind) {
          matchingFamilies += 1;
        }
      }
      expect(matchingFamilies, 1);
    }
  });

  test('test_run_event_from_json_property_rejects_altered_kinds', () {
    final Random random = seededRandom(5392);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject eventJson = randomRunEventJson(random);
      final String kind = eventJson[_kindField]! as String;
      final List<Object?> alteredKinds = <Object?>[
        kind.toUpperCase(),
        ' $kind',
        '${kind}_${randomText(random)}',
        '$kind ',
        <Object?>[kind],
      ];

      for (final Object? alteredKind in alteredKinds) {
        final JsonObject altered = Map<String, Object?>.of(eventJson);
        altered[_kindField] = alteredKind;

        expect(() => RunEvent.fromJson(altered), throwsFormatException);
      }
    }
  });

  test('test_run_event_from_json_property_kind_is_required', () {
    final Random random = seededRandom(5393);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject eventJson = randomRunEventJson(random);
      final JsonObject withoutKind = Map<String, Object?>.of(eventJson);
      withoutKind.remove(_kindField);
      final JsonObject nullKind = Map<String, Object?>.of(eventJson);
      nullKind[_kindField] = null;

      expect(() => RunEvent.fromJson(withoutKind), throwsFormatException);
      expect(() => RunEvent.fromJson(nullKind), throwsFormatException);
    }
  });
}
