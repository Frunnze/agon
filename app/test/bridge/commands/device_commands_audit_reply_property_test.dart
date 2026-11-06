import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/audit_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/commands/device_commands.dart';

import '../../support/random_inputs.dart';
import '../support/device_command_checks.dart';
import '../support/hostile_texts.dart';
import '../support/random_account_json.dart';
import '../support/wire_contract_checks.dart';

const int _wholeNumberSpan = 1 << 31;
const String _entriesField = 'entries';

const List<String> _auditViewFields = <String>[
  _entriesField,
  'entry_count',
  'head_hash',
  'intact',
];

const List<String> _auditEntryFields = <String>[
  'index',
  'at',
  'device_id',
  'event',
  'previous_hash',
  'hash',
];

const ListAuditCommand _listAudit = ListAuditCommand();

AuditView _decodeAuditReply(Object? replyJson) {
  return _listAudit.decodeReply(rereadJsonThroughText(replyJson));
}

void main() {
  test('test_list_audit_command_decode_reply_property_round_trips', () {
    final Random random = seededRandom(56131);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject replyJson = randomAuditViewJson(random);

      final List<Object?> sentEntries =
          replyJson[_entriesField]! as List<Object?>;

      final AuditView decoded = _decodeAuditReply(replyJson);

      expect(reencodeThroughText(decoded), equals(replyJson));
      expect(decoded.entries.length, sentEntries.length);
    }
  });

  test('test_list_audit_command_decode_reply_property_rejects_a_broken'
      '_field', () {
    final Random random = seededRandom(56132);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject auditJson = randomAuditViewJson(random);
      final JsonObject replyJson = withoutField(
        auditJson,
        pickOne(random, _auditViewFields),
      );

      expect(() => _decodeAuditReply(replyJson), throwsFormatException);
      expectWrongKindValuesAreRejected(random, auditJson, _decodeAuditReply);
    }
  });

  test('test_list_audit_command_decode_reply_property_rejects_non'
      '_objects', () {
    final Random random = seededRandom(56133);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject auditJson = randomAuditViewJson(random);
      final List<Object?> notObjects = <Object?>[
        auditJson[_entriesField],
        <Object?>[auditJson],
        null,
        randomHostileText(random),
        random.nextInt(_wholeNumberSpan),
        random.nextBool(),
      ];
      final Object? replyJson = pickOne(random, notObjects);

      expect(() => _decodeAuditReply(replyJson), throwsFormatException);
    }
  });

  test('test_list_audit_command_decode_reply_property_rejects_one_broken'
      '_entry', () {
    final Random random = seededRandom(56134);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject auditJson = randomAuditViewJson(random);
      final JsonObject brokenEntry = withoutField(
        randomAuditEntryJson(random),
        pickOne(random, _auditEntryFields),
      );
      final List<Object?> entries = <Object?>[
        ...auditJson[_entriesField]! as List<Object?>,
      ];
      entries.insert(random.nextInt(entries.length + 1), brokenEntry);
      final JsonObject replyJson = withFieldValue(
        auditJson,
        _entriesField,
        entries,
      );

      expect(() => _decodeAuditReply(replyJson), throwsFormatException);
    }
  });
}
