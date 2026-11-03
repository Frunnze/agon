import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';

bool isPlaceOffered({
  required AgentPlace place,
  required List<Runner> runners,
}) {
  for (final Runner runner in runners) {
    if (runner.online && runner.offers.contains(place)) {
      return true;
    }
  }
  return false;
}

bool isWaitingForPlace({
  required Run run,
  required AgentPlace place,
  required List<Runner> runners,
}) {
  if (!_isWaitingForRunner(run)) {
    return false;
  }
  return !isPlaceOffered(place: place, runners: runners);
}

bool _isWaitingForRunner(Run run) {
  if (!isRunActive(run)) {
    return false;
  }
  bool hasUnclaimedStep = false;
  for (final RunStep step in run.steps) {
    final bool isWorking =
        step.status == StepStatus.running ||
        step.status == StepStatus.waitingForApproval;
    if (isWorking) {
      return false;
    }
    if (step.status == StepStatus.waiting && step.runner == null) {
      hasUnclaimedStep = true;
    }
  }
  return hasUnclaimedStep;
}
