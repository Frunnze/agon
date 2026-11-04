import 'package:agent_orchestration/data/models/identifiers.dart';

abstract interface class RunWindowOpener {
  void openRunWindow({required RunId runId, required String title});
}
