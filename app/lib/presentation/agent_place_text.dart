import 'package:agent_orchestration/data/models/runner.dart';

const String agentPlaceTitle = 'Where agents run';
const String agentOffersTitle = 'What this computer offers';
const String agentOffersHint =
    'Each task says where its agents run. This computer takes only the '
    'tasks that ask for what it offers.';
const String taskPlaceHint =
    'Only runners that offer it take the task. A workflow runs all its '
    'agents there.';
const String containerNetworkTitle = 'Network in Docker';
const String runnerProblemTitle = "This computer can't run tasks";
const String runLocallyLabel = 'Also run agents on this computer';

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

String describeTaskPlace(AgentPlace place) {
  switch (place) {
    case AgentPlace.container:
      return 'In Docker';
    case AgentPlace.localProcess:
      return "On the runner's computer";
  }
}

String describeRunnerOffers(List<AgentPlace> offers) {
  final bool offersContainer = offers.contains(AgentPlace.container);
  final bool offersLocal = offers.contains(AgentPlace.localProcess);
  if (offersContainer && offersLocal) {
    return 'In Docker or on its own computer';
  }
  if (offersContainer) {
    return 'In Docker';
  }
  if (offersLocal) {
    return 'On its own computer';
  }
  return 'Nowhere right now';
}

String describeMissingPlaceTitle(AgentPlace place) {
  switch (place) {
    case AgentPlace.container:
      return 'No runner offers Docker right now';
    case AgentPlace.localProcess:
      return 'No runner runs agents on its own computer right now';
  }
}

String describeMissingPlaceDetail(AgentPlace place) {
  switch (place) {
    case AgentPlace.container:
      return "This task's agents run in Docker. It starts once an online "
          "runner offers Docker: tick In Docker on that runner's page.";
    case AgentPlace.localProcess:
      return "This task's agents run on the runner's computer. It starts "
          'once an online runner offers it: tick On this computer on that '
          "runner's page.";
  }
}
