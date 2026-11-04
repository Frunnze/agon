import 'package:agent_orchestration/startup/node_app_start.dart';

sealed class StartupStage {
  const StartupStage();
}

final class StartupWaiting extends StartupStage {
  const StartupWaiting();
}

final class StartupFailed extends StartupStage {
  const StartupFailed(this.problem);

  final Object problem;
}

final class StartupFinished extends StartupStage {
  const StartupFinished(this.started);

  final StartedApp started;
}
