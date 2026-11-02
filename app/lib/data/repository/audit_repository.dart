import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/models/audit.dart';

abstract interface class AuditRepository implements Listenable {
  List<AuditEntry> listEntries();

  Future<ChainSummary> verifyChain();
}
