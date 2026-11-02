import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/models/agent_login.dart';
import 'package:agent_orchestration/data/models/runner.dart';

abstract interface class AgentLoginRepository implements Listenable {
  AgentLoginStatus? findStatus();

  LoginTerminal? findTerminal();

  Future<void> checkStatus();

  Future<void> openTerminal(AgentPlace place);

  Future<void> typeIntoTerminal(String keys);

  Future<void> closeTerminal();

  Future<void> saveApiKey(String apiKey);

  Future<void> forgetCredential();
}
