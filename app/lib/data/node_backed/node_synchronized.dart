import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;

abstract interface class NodeSynchronized {
  Future<void> load();

  Future<void> applyChange(node.ChangeTopic topic);
}
