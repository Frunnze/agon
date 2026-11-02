import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/live_run_values.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

final class WatchRunCommand implements NodeCommand<WatchView> {
  const WatchRunCommand({required this.runId});

  final RunId runId;

  @override
  String get name => 'watch_run';

  @override
  JsonObject get arguments => <String, Object?>{'run_id': runId.value};

  @override
  WatchView decodeReply(Object? okValue) => WatchView.fromJson(okValue);
}

final class StopWatchingRunCommand implements NodeCommand<void> {
  const StopWatchingRunCommand({required this.runId});

  final RunId runId;

  @override
  String get name => 'stop_watching_run';

  @override
  JsonObject get arguments => <String, Object?>{'run_id': runId.value};

  @override
  void decodeReply(Object? okValue) => decodeNothing(okValue);
}
