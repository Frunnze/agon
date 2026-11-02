import 'package:agent_orchestration/bridge/codecs/identifier_codecs.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

enum ChangeArea implements WireNamed {
  account('account'),
  pairing('pairing'),
  devices('devices'),
  workspaces('workspaces'),
  projects('projects'),
  workflows('workflows'),
  skills('skills'),
  rules('rules'),
  tasks('tasks'),
  runners('runners'),
  approvals('approvals'),
  audit('audit'),
  serverGroup('server_group');

  const ChangeArea(this.wireName);

  @override
  final String wireName;

  static ChangeArea decode(Object? json) => decodeWireName(values, json);
}

sealed class ChangeTopic implements JsonEncodable {
  const ChangeTopic();

  factory ChangeTopic.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    final String topic = readField(fields, 'topic', decodeText);
    if (topic == RunChanged.topic) {
      return RunChanged(runId: readField(fields, 'run_id', decodeRunId));
    }
    return AreaChanged(area: ChangeArea.decode(topic));
  }
}

final class AreaChanged extends ChangeTopic {
  const AreaChanged({required this.area});

  final ChangeArea area;

  @override
  JsonObject toJson() => <String, Object?>{'topic': area.wireName};
}

final class RunChanged extends ChangeTopic {
  const RunChanged({required this.runId});

  static const String topic = 'run';

  final RunId runId;

  @override
  JsonObject toJson() {
    return <String, Object?>{'topic': topic, 'run_id': runId.value};
  }
}

final class ChangeNotification implements JsonEncodable {
  const ChangeNotification({required this.sequence, required this.topic});

  factory ChangeNotification.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return ChangeNotification(
      sequence: readField(fields, 'sequence', decodeInteger),
      topic: readField(fields, 'topic', ChangeTopic.fromJson),
    );
  }

  final int sequence;
  final ChangeTopic topic;

  @override
  JsonObject toJson() {
    return <String, Object?>{'sequence': sequence, 'topic': topic.toJson()};
  }
}

final class EventsResponse implements JsonEncodable {
  EventsResponse({
    required List<ChangeNotification> notifications,
    required this.latestSequence,
  }) : notifications = List<ChangeNotification>.unmodifiable(notifications);

  factory EventsResponse.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return EventsResponse(
      notifications: readListField(
        fields,
        'notifications',
        ChangeNotification.fromJson,
      ),
      latestSequence: readField(fields, 'latest_sequence', decodeInteger),
    );
  }

  final List<ChangeNotification> notifications;
  final int latestSequence;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'notifications': encodeList(notifications),
      'latest_sequence': latestSequence,
    };
  }
}
