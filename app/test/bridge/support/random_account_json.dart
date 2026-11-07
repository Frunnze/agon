import 'dart:math';

import '../../support/random_inputs.dart';
import 'node_json_primitives.dart';
import 'node_wire_names.dart';
import 'random_catalog_json.dart';
import 'random_wire_counts.dart';

Map<String, Object?> randomAccountSummaryJson(Random random) {
  return <String, Object?>{
    'device': randomDeviceJson(random),
    'workspaces': randomListOf(random, randomWorkspaceJson),
  };
}

Map<String, Object?> randomServerHealthJson(Random random) {
  return <String, Object?>{
    'reachable': random.nextBool(),
    'checked_at': randomMomentText(random),
    'problem': randomOptional(random, randomText),
  };
}

Map<String, Object?> randomPendingJoinJson(Random random) {
  return <String, Object?>{
    'join_id': randomUuidText(random),
    'display_code': randomText(random),
  };
}

Map<String, Object?> randomStatusViewJson(Random random) {
  return <String, Object?>{
    'server_address': randomOptional(random, randomText),
    'server_reachable': random.nextBool(),
    'hosted_server_address': randomOptional(random, randomText),
    'device_id': randomOptional(random, randomDeviceIdText),
    'account': randomOptional(random, randomAccountSummaryJson),
    'pending_join': randomOptional(random, randomPendingJoinJson),
    'peer': randomOptional(random, randomPeerAnnouncementJson),
    'rendezvous_problem': randomOptional(random, randomText),
    'runner_settings': randomOptional(random, randomRunnerSettingsJson),
    'app_servers': randomAppServersJson(random),
  };
}

Map<String, Object?> randomBackupCopyJson(Random random) {
  return <String, Object?>{
    'changes_behind': random.nextInt(100000),
    'verified_at': randomMomentText(random),
  };
}

Map<String, Object?> randomAppServerJson(Random random) {
  return <String, Object?>{
    'device_id': randomDeviceIdText(random),
    'standing': pickOne(random, nodeServerStandings),
    'copy': randomOptional(random, randomBackupCopyJson),
  };
}

Map<String, Object?> randomAppServersJson(Random random) {
  return <String, Object?>{
    'servers': randomListOf(random, randomAppServerJson),
    'this_device': pickOne(random, nodeThisDeviceStandings),
    'can_keep_backup': random.nextBool(),
  };
}

Map<String, Object?> randomPeerAddressJson(Random random) {
  return <String, Object?>{
    'endpoint_public_key': randomEndpointPublicKey(random),
    'direct_addresses': randomTexts(random),
    'relay_url': randomOptional(random, randomText),
  };
}

Map<String, Object?> randomPeerAnnouncementJson(Random random) {
  return <String, Object?>{
    'published_address': randomOptional(random, randomPeerAddressJson),
    'problem': randomOptional(random, randomText),
  };
}

Map<String, Object?> randomSandboxSettingsJson(Random random) {
  final List<Map<String, Object?>> sandboxes = <Map<String, Object?>>[
    <String, Object?>{'kind': 'local_process'},
    <String, Object?>{
      'kind': 'container',
      'engine': pickOne(random, nodeContainerEngines),
      'image': randomText(random),
      'allowed_hosts': randomTexts(random),
    },
  ];
  return pickOne(random, sandboxes);
}

Map<String, Object?> randomRunnerSettingsJson(Random random) {
  return <String, Object?>{
    'labels': randomTexts(random),
    'slot_capacity': randomCount(random),
    'sandbox': randomSandboxSettingsJson(random),
    'clone_url_template': randomOptional(random, randomText),
    'passed_environment': randomTexts(random),
  };
}

Map<String, Object?> randomJoiningDeviceJson(Random random) {
  return <String, Object?>{
    'name': randomText(random),
    'role': pickOne(random, nodeDeviceRoles),
    'kind': pickOne(random, nodeDeviceKinds),
    'key_kind': pickOne(random, nodeHardwareKeyKinds),
    'sealing_public_key': randomBytes(random),
    'fingerprint_words': randomTexts(random),
  };
}

Map<String, Object?> randomPairingRequestScreenJson(Random random) {
  return <String, Object?>{
    'code': randomText(random),
    'display_code': randomText(random),
    'started_at': randomMomentText(random),
    'expires_at': randomMomentText(random),
    'joining': randomOptional(random, randomJoiningDeviceJson),
  };
}

Map<String, Object?> randomStartedPairingJson(Random random) {
  return <String, Object?>{
    ...randomPairingRequestScreenJson(random),
    'rendezvous_problem': randomOptional(random, randomText),
  };
}

Map<String, Object?> randomJoinStatusJson(Random random) {
  final List<Map<String, Object?>> states = <Map<String, Object?>>[
    <String, Object?>{
      'state': 'waiting',
      'fingerprint_words': randomTexts(random),
    },
    <String, Object?>{
      'state': 'approved',
      'fingerprint_words': randomTexts(random),
      ...randomAccountSummaryJson(random),
    },
    <String, Object?>{
      'state': 'rejected',
      'fingerprint_words': randomTexts(random),
    },
    <String, Object?>{
      'state': 'expired',
      'fingerprint_words': randomTexts(random),
    },
  ];
  return pickOne(random, states);
}

Map<String, Object?> randomChangeTopicJson(Random random) {
  final List<Map<String, Object?>> topics = <Map<String, Object?>>[
    <String, Object?>{'topic': pickOne(random, nodeChangeAreas)},
    <String, Object?>{'topic': 'run', 'run_id': randomUuidText(random)},
  ];
  return pickOne(random, topics);
}

Map<String, Object?> randomChangeNotificationJson(Random random) {
  return <String, Object?>{
    'sequence': randomCount(random),
    'topic': randomChangeTopicJson(random),
  };
}

Map<String, Object?> randomEventsResponseJson(Random random) {
  return <String, Object?>{
    'notifications': randomListOf(random, randomChangeNotificationJson),
    'latest_sequence': randomCount(random),
  };
}

Map<String, Object?> randomAuditEntryJson(Random random) {
  return <String, Object?>{
    'index': randomCount(random),
    'at': randomMomentText(random),
    'device_id': randomDeviceIdText(random),
    'event': randomText(random),
    'detail': randomOptional(random, randomText),
    'previous_hash': randomText(random),
    'hash': randomText(random),
  };
}

Map<String, Object?> randomAuditViewJson(Random random) {
  return <String, Object?>{
    'entries': randomListOf(random, randomAuditEntryJson),
    'entry_count': randomCount(random),
    'head_hash': randomText(random),
    'intact': random.nextBool(),
  };
}
