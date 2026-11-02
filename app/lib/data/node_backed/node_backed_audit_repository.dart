import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/bridge/codecs/audit_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/bridge/commands/device_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/models/audit.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/audit_repository.dart';

const String _brokenChainProblem =
    'The audit log is broken: an entry does not match the one before it';

final class NodeBackedAuditRepository extends ChangeNotifier
    implements AuditRepository, NodeSynchronized {
  NodeBackedAuditRepository({required NodeCommandChannel channel})
    : _channel = channel;

  final NodeCommandChannel _channel;
  final FetchSequence _fetches = FetchSequence();
  List<AuditEntry> _entries = const <AuditEntry>[];

  @override
  List<AuditEntry> listEntries() => _entries;

  @override
  Future<void> load() async {
    await _fetchAudit();
  }

  @override
  Future<void> applyChange(node.ChangeTopic topic) async {
    await _fetchAudit();
  }

  @override
  Future<ChainSummary> verifyChain() async {
    final node.AuditView audit = await _fetchAudit();
    if (!audit.intact) {
      throw StateError(_brokenChainProblem);
    }
    return mapChainSummaryFromNode(audit);
  }

  Future<node.AuditView> _fetchAudit() async {
    final int fetch = _fetches.startFetch();
    final node.AuditView audit = await executeNodeCommand(
      _channel,
      const node.ListAuditCommand(),
    );
    if (!_fetches.acceptIfNewest(fetch)) {
      return audit;
    }

    _entries = mapAuditEntriesFromNode(audit);
    notifyListeners();
    return audit;
  }
}
