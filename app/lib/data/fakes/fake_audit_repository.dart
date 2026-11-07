import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/models/audit.dart';
import 'package:agent_orchestration/data/repository/audit_repository.dart';

const String _genesisHash =
    '0000000000000000000000000000000000000000000000000000000000000000';
const ChainSummary _emptyChainSummary = ChainSummary(
  entryCount: 0,
  headHash: _genesisHash,
);

final class FakeAuditRepository extends ChangeNotifier
    implements AuditRepository {
  FakeAuditRepository({required List<AuditEntry> entries})
    : _entries = List<AuditEntry>.unmodifiable(entries);

  final List<AuditEntry> _entries;

  @override
  List<AuditEntry> listEntries() => _entries;

  @override
  Future<ChainSummary> verifyChain() async {
    for (int index = 1; index < _entries.length; index += 1) {
      final AuditEntry newer = _entries[index - 1];
      final AuditEntry older = _entries[index];
      final bool isLinked = newer.previousHash == older.hash;
      final bool isNextIndex = newer.index == older.index + 1;
      if (!isLinked || !isNextIndex) {
        throw StateError('Audit entry ${newer.index} breaks the chain');
      }
    }

    if (_entries.isEmpty) {
      return _emptyChainSummary;
    }
    final AuditEntry newest = _entries.first;
    return ChainSummary(entryCount: newest.index + 1, headHash: newest.hash);
  }
}
