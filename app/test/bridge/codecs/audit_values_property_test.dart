import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/audit_values.dart';

import '../../support/random_inputs.dart';
import '../support/list_copy_properties.dart';
import '../support/random_account_json.dart';
import '../support/random_typed_values.dart';
import '../support/utc_offset_moments.dart';
import '../support/wire_codec_properties.dart';

const List<WireCodec> _auditCodecs = <WireCodec>[
  WireCodec(
    typeName: 'audit_entry_view',
    seed: 49600,
    buildJson: randomAuditEntryJson,
    decode: AuditEntryView.fromJson,
    requiredFields: <String>{
      'index',
      'at',
      'device_id',
      'event',
      'previous_hash',
      'hash',
    },
    optionalFields: <String>{'detail'},
  ),
  WireCodec(
    typeName: 'audit_view',
    seed: 49610,
    buildJson: randomAuditViewJson,
    decode: AuditView.fromJson,
    requiredFields: <String>{'entries', 'entry_count', 'head_hash', 'intact'},
    optionalFields: <String>{},
  ),
];

void main() {
  for (final WireCodec codec in _auditCodecs) {
    testWireDecodingProperties(codec);
    testWireEncodingProperties(codec);
  }

  testListCopyProperties(
    const ListCopy<AuditView, AuditEntryView>(
      testNamePrefix: 'test_audit_view_constructor_property_entries',
      seed: 49620,
      buildElement: _buildAuditEntry,
      construct: _buildAuditView,
      readList: _readEntries,
    ),
  );

  test('test_audit_entry_view_from_json_property_any_offset_keeps_the_at', () {
    final Random random = seededRandom(49630);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime at = randomMicrosecondMoment(random).toUtc();
      final Map<String, Object?> wireJson = randomAuditEntryJson(random);
      wireJson['at'] = writeMomentAtRandomOffset(random, at);

      final AuditEntryView entry = AuditEntryView.fromJson(wireJson);

      expect(entry.at, at);
      expect(entry.at.isUtc, isTrue);
    }
  });

  test('test_audit_entry_view_to_json_property_writes_at_as_utc_text', () {
    final Random random = seededRandom(49631);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime at = randomMicrosecondMoment(random);
      final AuditEntryView entry = AuditEntryView(
        index: random.nextInt(propertyIterations),
        at: at,
        deviceId: randomDeviceId(random),
        event: randomText(random),
        detail: null,
        previousHash: randomText(random),
        hash: randomText(random),
      );

      expectUtcMomentText(entry.toJson()['at'], at);
    }
  });
}

AuditEntryView _buildAuditEntry(Random random) {
  return AuditEntryView.fromJson(randomAuditEntryJson(random));
}

AuditView _buildAuditView(Random random, List<AuditEntryView> entries) {
  return AuditView(
    entries: entries,
    entryCount: entries.length,
    headHash: randomText(random),
    intact: random.nextBool(),
  );
}

List<AuditEntryView> _readEntries(AuditView view) => view.entries;
