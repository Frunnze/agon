import 'package:agent_orchestration/data/models/runner.dart';

const String agentPlaceTitle = 'Where agents run';
const String runnerProblemTitle = "This computer can't run tasks";
const String runLocallyLabel = 'Run agents on this computer instead';

String describeAgentPlaceTitle(AgentPlace place) {
  switch (place) {
    case AgentPlace.container:
      return 'In Docker';
    case AgentPlace.localProcess:
      return 'On this computer';
  }
}

String describeAgentPlaceDetail(AgentPlace place) {
  switch (place) {
    case AgentPlace.container:
      return 'A new container for each run, deleted when the run ends. '
          'Needs Docker running and the runner image.';
    case AgentPlace.localProcess:
      return "Agents run as programs here and edit the task's worktree. "
          'Faster, less isolated.';
  }
}
