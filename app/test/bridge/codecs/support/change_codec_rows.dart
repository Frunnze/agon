import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/change_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/skill_change_values.dart';

import '../../support/random_account_json.dart';
import '../../support/random_catalog_json.dart';
import 'codec_rows.dart';

const List<ConstructorRow> changeConstructorRows = <ConstructorRow>[
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'skill_change_origin',
      buildJson: randomSkillChangeOriginJson,
      decode: SkillChangeOrigin.fromJson,
    ),
    rebuild: _rebuildSkillChangeOrigin,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'person_edit',
      buildJson: randomPersonEditJson,
      decode: SkillChangeOrigin.fromJson,
    ),
    rebuild: _rebuildSkillChangeOrigin,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'approved_agent_run',
      buildJson: randomApprovedAgentRunJson,
      decode: SkillChangeOrigin.fromJson,
    ),
    rebuild: _rebuildSkillChangeOrigin,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'automatic_agent_run',
      buildJson: randomAutomaticAgentRunJson,
      decode: SkillChangeOrigin.fromJson,
    ),
    rebuild: _rebuildSkillChangeOrigin,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'skill_change',
      buildJson: randomSkillChangeJson,
      decode: SkillChange.fromJson,
    ),
    rebuild: _rebuildSkillChange,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'change_topic',
      buildJson: randomChangeTopicJson,
      decode: ChangeTopic.fromJson,
    ),
    rebuild: _rebuildChangeTopic,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'area_changed',
      buildJson: randomAreaChangedJson,
      decode: ChangeTopic.fromJson,
    ),
    rebuild: _rebuildChangeTopic,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'run_changed',
      buildJson: randomRunChangedJson,
      decode: ChangeTopic.fromJson,
    ),
    rebuild: _rebuildChangeTopic,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'change_notification',
      buildJson: randomChangeNotificationJson,
      decode: ChangeNotification.fromJson,
    ),
    rebuild: _rebuildChangeNotification,
  ),
];

const List<EncodableRow> changeEncodableRows = <EncodableRow>[
  EncodableRow(
    typeName: 'events_response',
    buildJson: randomEventsResponseJson,
    decode: EventsResponse.fromJson,
  ),
];

Object? randomPersonEditJson(Random random) {
  return randomJsonOfKind<PersonEdit>(
    random: random,
    buildJson: randomSkillChangeOriginJson,
    decode: SkillChangeOrigin.fromJson,
  );
}

Object? randomApprovedAgentRunJson(Random random) {
  return randomJsonOfKind<ApprovedAgentRun>(
    random: random,
    buildJson: randomSkillChangeOriginJson,
    decode: SkillChangeOrigin.fromJson,
  );
}

Object? randomAutomaticAgentRunJson(Random random) {
  return randomJsonOfKind<AutomaticAgentRun>(
    random: random,
    buildJson: randomSkillChangeOriginJson,
    decode: SkillChangeOrigin.fromJson,
  );
}

Object? randomAreaChangedJson(Random random) {
  return randomJsonOfKind<AreaChanged>(
    random: random,
    buildJson: randomChangeTopicJson,
    decode: ChangeTopic.fromJson,
  );
}

Object? randomRunChangedJson(Random random) {
  return randomJsonOfKind<RunChanged>(
    random: random,
    buildJson: randomChangeTopicJson,
    decode: ChangeTopic.fromJson,
  );
}

JsonEncodable _rebuildSkillChangeOrigin(JsonEncodable value) {
  final SkillChangeOrigin origin = value as SkillChangeOrigin;
  return switch (origin) {
    PersonEdit() => const PersonEdit(),
    ApprovedAgentRun() => ApprovedAgentRun(runId: origin.runId),
    AutomaticAgentRun() => AutomaticAgentRun(runId: origin.runId),
  };
}

JsonEncodable _rebuildSkillChange(JsonEncodable value) {
  final SkillChange change = value as SkillChange;
  return SkillChange(
    origin: change.origin,
    savedAt: change.savedAt,
    replacedInstructions: change.replacedInstructions,
  );
}

JsonEncodable _rebuildChangeTopic(JsonEncodable value) {
  final ChangeTopic topic = value as ChangeTopic;
  return switch (topic) {
    AreaChanged() => AreaChanged(area: topic.area),
    RunChanged() => RunChanged(runId: topic.runId),
  };
}

JsonEncodable _rebuildChangeNotification(JsonEncodable value) {
  final ChangeNotification notification = value as ChangeNotification;
  return ChangeNotification(
    sequence: notification.sequence,
    topic: notification.topic,
  );
}
