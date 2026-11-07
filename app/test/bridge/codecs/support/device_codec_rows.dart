import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/device_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/library_values.dart';
import 'package:agent_orchestration/bridge/codecs/server_group_values.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../support/random_account_json.dart';
import '../../support/random_catalog_json.dart';
import 'codec_rows.dart';

const List<ConstructorRow> deviceConstructorRows = <ConstructorRow>[
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'runner_target',
      buildJson: randomRunnerTargetJson,
      decode: RunnerTarget.fromJson,
    ),
    rebuild: _rebuildRunnerTarget,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'any_free_runner',
      buildJson: randomAnyFreeRunnerJson,
      decode: RunnerTarget.fromJson,
    ),
    rebuild: _rebuildRunnerTarget,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'specific_runner',
      buildJson: randomSpecificRunnerJson,
      decode: RunnerTarget.fromJson,
    ),
    rebuild: _rebuildRunnerTarget,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'backup_copy_view',
      buildJson: randomBackupCopyJson,
      decode: BackupCopyView.fromJson,
    ),
    rebuild: _rebuildBackupCopyView,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'app_server_view',
      buildJson: randomAppServerJson,
      decode: AppServerView.fromJson,
    ),
    rebuild: _rebuildAppServerView,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'rule',
      buildJson: randomRuleJson,
      decode: Rule.fromJson,
    ),
    rebuild: _rebuildRule,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'agents_markdown_view',
      buildJson: randomAgentsMarkdownJson,
      decode: AgentsMarkdownView.fromJson,
    ),
    rebuild: _rebuildAgentsMarkdownView,
  ),
];

const List<EncodableRow> deviceEncodableRows = <EncodableRow>[
  EncodableRow(
    typeName: 'device',
    buildJson: randomDeviceJson,
    decode: Device.fromJson,
  ),
  EncodableRow(
    typeName: 'runner',
    buildJson: randomRunnerJson,
    decode: Runner.fromJson,
  ),
  EncodableRow(
    typeName: 'runner_with_labels',
    buildJson: randomRunnerWithLabelsJson,
    decode: RunnerTarget.fromJson,
  ),
  EncodableRow(
    typeName: 'app_servers_view',
    buildJson: randomAppServersJson,
    decode: AppServersView.fromJson,
  ),
  EncodableRow(
    typeName: 'skill',
    buildJson: randomSkillJson,
    decode: Skill.fromJson,
  ),
];

Object? randomAnyFreeRunnerJson(Random random) {
  return randomJsonOfKind<AnyFreeRunner>(
    random: random,
    buildJson: randomRunnerTargetJson,
    decode: RunnerTarget.fromJson,
  );
}

Object? randomSpecificRunnerJson(Random random) {
  return randomJsonOfKind<SpecificRunner>(
    random: random,
    buildJson: randomRunnerTargetJson,
    decode: RunnerTarget.fromJson,
  );
}

Object? randomRunnerWithLabelsJson(Random random) {
  return randomJsonOfKind<RunnerWithLabels>(
    random: random,
    buildJson: randomRunnerTargetJson,
    decode: RunnerTarget.fromJson,
  );
}

JsonEncodable _rebuildRunnerTarget(JsonEncodable value) {
  final RunnerTarget target = value as RunnerTarget;
  return switch (target) {
    AnyFreeRunner() => const AnyFreeRunner(),
    SpecificRunner(:final DeviceId deviceId) => SpecificRunner(
      deviceId: deviceId,
    ),
    RunnerWithLabels(:final List<String> labels) => RunnerWithLabels(
      labels: labels,
    ),
  };
}

JsonEncodable _rebuildBackupCopyView(JsonEncodable value) {
  final BackupCopyView copy = value as BackupCopyView;
  return BackupCopyView(
    changesBehind: copy.changesBehind,
    verifiedAt: copy.verifiedAt,
  );
}

JsonEncodable _rebuildAppServerView(JsonEncodable value) {
  final AppServerView server = value as AppServerView;
  return AppServerView(
    deviceId: server.deviceId,
    standing: server.standing,
    copy: server.copy,
  );
}

JsonEncodable _rebuildRule(JsonEncodable value) {
  final Rule rule = value as Rule;
  return Rule(
    id: rule.id,
    title: rule.title,
    details: rule.details,
    scope: rule.scope,
    enabled: rule.enabled,
    addedAt: rule.addedAt,
  );
}

JsonEncodable _rebuildAgentsMarkdownView(JsonEncodable value) {
  final AgentsMarkdownView view = value as AgentsMarkdownView;
  return AgentsMarkdownView(markdown: view.markdown);
}
