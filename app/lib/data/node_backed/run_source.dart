import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';

abstract interface class RunSource implements Listenable {
  Run findRun(RunId runId);

  Future<Run> refreshRun(RunId runId);
}
