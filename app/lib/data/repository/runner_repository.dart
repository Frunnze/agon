import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';

abstract interface class RunnerRepository implements Listenable {
  List<Runner> listRunners();

  Runner findRunner(DeviceId deviceId);

  Future<Runner> pauseRunner(DeviceId deviceId);

  Future<Runner> resumeRunner(DeviceId deviceId);

  AgentPlace? findThisAgentPlace();

  String? findThisRunnerProblem();

  Future<void> chooseAgentPlace(AgentPlace place);
}
