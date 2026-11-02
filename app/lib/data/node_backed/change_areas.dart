import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;

bool isChangeInAreas(node.ChangeTopic topic, Set<node.ChangeArea> areas) {
  return topic is node.AreaChanged && areas.contains(topic.area);
}
