import 'dart:math';

import '../../support/random_inputs.dart';
import 'node_json_primitives.dart';
import 'node_wire_names.dart';
import 'random_account_json.dart';

Map<String, Object?> randomDeviceJson(Random random) {
  return <String, Object?>{
    'id': randomDeviceIdText(random),
    'name': randomText(random),
    'role': pickOne(random, nodeDeviceRoles),
    'key_kind': pickOne(random, nodeHardwareKeyKinds),
    'signing_public_key': randomBytes(random),
    'sealing_public_key': randomBytes(random),
    'workspaces': randomUuidTexts(random),
    'paired_at': randomMomentText(random),
    'approved_by': randomOptional(random, randomDeviceIdText),
    'last_seen': randomMomentText(random),
    'revoked': random.nextBool(),
  };
}

Map<String, Object?> randomRunnerJson(Random random) {
  return <String, Object?>{
    'device_id': randomDeviceIdText(random),
    'labels': randomTexts(random),
    'slots_total': randomCount(random),
    'slots_busy': randomCount(random),
    'link': pickOne(random, nodeRunnerLinks),
    'online': random.nextBool(),
    'accepting_new_runs': random.nextBool(),
    'sandbox': pickOne(random, nodeSandboxKinds),
    'allowed_hosts': randomTexts(random),
  };
}

Map<String, Object?> randomRunnerTargetJson(Random random) {
  final List<Map<String, Object?>> targets = <Map<String, Object?>>[
    <String, Object?>{'kind': 'any_free_runner'},
    <String, Object?>{
      'kind': 'specific_runner',
      'device_id': randomDeviceIdText(random),
    },
    <String, Object?>{
      'kind': 'runner_with_labels',
      'labels': randomTexts(random),
    },
  ];
  return pickOne(random, targets);
}

Map<String, Object?> randomWorkspaceJson(Random random) {
  return <String, Object?>{
    'id': randomUuidText(random),
    'name': randomText(random),
    'app_server_address': randomText(random),
  };
}

Map<String, Object?> randomRepositoryJson(Random random) {
  return <String, Object?>{
    'address': randomText(random),
    'default_branch': randomText(random),
    'agent_access': pickOne(random, nodeAgentAccesses),
  };
}

Map<String, Object?> randomProjectJson(Random random) {
  return <String, Object?>{
    'id': randomUuidText(random),
    'workspace_id': randomUuidText(random),
    'name': randomText(random),
    'repositories': randomListOf(random, randomRepositoryJson),
  };
}

Map<String, Object?> randomWorkspaceScopeJson(Random random) {
  final List<Map<String, Object?>> scopes = <Map<String, Object?>>[
    <String, Object?>{'kind': 'all_workspaces'},
    <String, Object?>{
      'kind': 'only_workspaces',
      'workspaces': randomUuidTexts(random),
    },
  ];
  return pickOne(random, scopes);
}

Map<String, Object?> randomProjectScopeJson(Random random) {
  final List<Map<String, Object?>> scopes = <Map<String, Object?>>[
    <String, Object?>{'kind': 'all_projects'},
    <String, Object?>{
      'kind': 'only_projects',
      'projects': randomUuidTexts(random),
    },
  ];
  return pickOne(random, scopes);
}

Map<String, Object?> randomScopeJson(Random random) {
  return <String, Object?>{
    'workspaces': randomWorkspaceScopeJson(random),
    'projects': randomProjectScopeJson(random),
  };
}

Map<String, Object?> randomSkillJson(Random random) {
  return <String, Object?>{
    'id': randomUuidText(random),
    'name': randomText(random),
    'summary': randomText(random),
    'instructions': randomText(random),
    'scope': randomScopeJson(random),
    'usage': pickOne(random, nodeSkillUsages),
    'source': pickOne(random, nodeSkillSources),
  };
}

Map<String, Object?> randomRuleJson(Random random) {
  return <String, Object?>{
    'id': randomUuidText(random),
    'title': randomText(random),
    'details': randomText(random),
    'scope': randomScopeJson(random),
    'enabled': random.nextBool(),
    'added_at': randomMomentText(random),
  };
}

Map<String, Object?> randomAgentsMarkdownJson(Random random) {
  return <String, Object?>{'markdown': randomText(random)};
}

Map<String, Object?> randomDeviceViewJson(Random random) {
  return <String, Object?>{
    'device': randomDeviceJson(random),
    'is_this_device': random.nextBool(),
    'workspace_names': randomTexts(random),
    'peer_address_verified': random.nextBool(),
  };
}

Map<String, Object?> randomWorkspaceViewJson(Random random) {
  return <String, Object?>{
    'workspace': randomWorkspaceJson(random),
    'project_count': randomCount(random),
    'runner_count': randomCount(random),
  };
}

Map<String, Object?> randomProjectViewJson(Random random) {
  return <String, Object?>{
    'project': randomProjectJson(random),
    'task_count': randomCount(random),
    'running_task_count': randomCount(random),
  };
}

Map<String, Object?> randomRunnerSummaryJson(Random random) {
  return <String, Object?>{
    'runner_count': randomCount(random),
    'online_count': randomCount(random),
    'free_slot_count': randomCount(random),
  };
}

Map<String, Object?> randomRunnerViewJson(Random random) {
  return <String, Object?>{
    'runner': randomRunnerJson(random),
    'device_name': randomText(random),
    'free_slots': randomCount(random),
    'peer_address_verified': random.nextBool(),
  };
}

Map<String, Object?> randomRunnersViewJson(Random random) {
  return <String, Object?>{
    'summary': randomRunnerSummaryJson(random),
    'summary_text': randomText(random),
    'runners': randomListOf(random, randomRunnerViewJson),
    'this_device_problem': randomOptional(random, randomText),
    'this_device_settings': randomOptional(random, randomRunnerSettingsJson),
  };
}
