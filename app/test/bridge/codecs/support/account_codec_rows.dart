import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/account_values.dart';
import 'package:agent_orchestration/bridge/codecs/agent_login_values.dart';
import 'package:agent_orchestration/bridge/codecs/audit_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/pairing_values.dart';
import 'package:agent_orchestration/bridge/codecs/person_step_values.dart';

import '../../support/agent_login_command_shapes.dart';
import '../../support/random_account_json.dart';
import '../../support/random_branching_json.dart';
import 'codec_rows.dart';

const List<ConstructorRow> accountConstructorRows = <ConstructorRow>[
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'server_health_view',
      buildJson: randomServerHealthJson,
      decode: ServerHealthView.fromJson,
    ),
    rebuild: _rebuildServerHealthView,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'pending_join',
      buildJson: randomPendingJoinJson,
      decode: PendingJoin.fromJson,
    ),
    rebuild: _rebuildPendingJoin,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'peer_announcement',
      buildJson: randomPeerAnnouncementJson,
      decode: PeerAnnouncement.fromJson,
    ),
    rebuild: _rebuildPeerAnnouncement,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'status_view',
      buildJson: randomStatusViewJson,
      decode: StatusView.fromJson,
    ),
    rebuild: _rebuildStatusView,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'agent_login_status_view',
      buildJson: randomAgentLoginStatusJson,
      decode: AgentLoginStatusView.fromJson,
    ),
    rebuild: _rebuildAgentLoginStatusView,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'audit_entry_view',
      buildJson: randomAuditEntryJson,
      decode: AuditEntryView.fromJson,
    ),
    rebuild: _rebuildAuditEntryView,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'joining_device',
      buildJson: randomJoiningDeviceJson,
      decode: JoiningDevice.fromJson,
    ),
    rebuild: _rebuildJoiningDevice,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'pairing_request_screen',
      buildJson: randomPairingRequestScreenJson,
      decode: PairingRequestScreen.fromJson,
    ),
    rebuild: _rebuildPairingRequestScreen,
  ),
  ConstructorRow(
    encodable: joinStatusViewRow,
    rebuild: _rebuildJoinStatusView,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'join_waiting',
      buildJson: randomJoinWaitingJson,
      decode: JoinStatusView.fromJson,
    ),
    rebuild: _rebuildJoinStatusView,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'join_approved',
      buildJson: randomJoinApprovedJson,
      decode: JoinStatusView.fromJson,
    ),
    rebuild: _rebuildJoinStatusView,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'join_rejected',
      buildJson: randomJoinRejectedJson,
      decode: JoinStatusView.fromJson,
    ),
    rebuild: _rebuildJoinStatusView,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'join_expired',
      buildJson: randomJoinExpiredJson,
      decode: JoinStatusView.fromJson,
    ),
    rebuild: _rebuildJoinStatusView,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'open_person_step',
      buildJson: randomOpenPersonStepJson,
      decode: OpenPersonStep.fromJson,
    ),
    rebuild: _rebuildOpenPersonStep,
  ),
];

const EncodableRow joinStatusViewRow = EncodableRow(
  typeName: 'join_status_view',
  buildJson: randomJoinStatusJson,
  decode: JoinStatusView.fromJson,
);

const List<EncodableRow> accountEncodableRows = <EncodableRow>[
  EncodableRow(
    typeName: 'account_summary',
    buildJson: randomAccountSummaryJson,
    decode: AccountSummary.fromJson,
  ),
  EncodableRow(
    typeName: 'peer_address',
    buildJson: randomPeerAddressJson,
    decode: PeerAddress.fromJson,
  ),
  EncodableRow(
    typeName: 'agent_login_view',
    buildJson: randomAgentLoginJson,
    decode: AgentLoginView.fromJson,
  ),
  EncodableRow(
    typeName: 'audit_view',
    buildJson: randomAuditViewJson,
    decode: AuditView.fromJson,
  ),
];

Object? randomJoinWaitingJson(Random random) {
  return randomJsonOfKind<JoinWaiting>(
    random: random,
    buildJson: randomJoinStatusJson,
    decode: JoinStatusView.fromJson,
  );
}

Object? randomJoinApprovedJson(Random random) {
  return randomJsonOfKind<JoinApproved>(
    random: random,
    buildJson: randomJoinStatusJson,
    decode: JoinStatusView.fromJson,
  );
}

Object? randomJoinRejectedJson(Random random) {
  return randomJsonOfKind<JoinRejected>(
    random: random,
    buildJson: randomJoinStatusJson,
    decode: JoinStatusView.fromJson,
  );
}

Object? randomJoinExpiredJson(Random random) {
  return randomJsonOfKind<JoinExpired>(
    random: random,
    buildJson: randomJoinStatusJson,
    decode: JoinStatusView.fromJson,
  );
}

JsonEncodable _rebuildServerHealthView(JsonEncodable value) {
  final ServerHealthView health = value as ServerHealthView;
  return ServerHealthView(
    reachable: health.reachable,
    checkedAt: health.checkedAt,
    problem: health.problem,
  );
}

JsonEncodable _rebuildPendingJoin(JsonEncodable value) {
  final PendingJoin join = value as PendingJoin;
  return PendingJoin(joinId: join.joinId, displayCode: join.displayCode);
}

JsonEncodable _rebuildPeerAnnouncement(JsonEncodable value) {
  final PeerAnnouncement announcement = value as PeerAnnouncement;
  return PeerAnnouncement(
    publishedAddress: announcement.publishedAddress,
    problem: announcement.problem,
  );
}

JsonEncodable _rebuildStatusView(JsonEncodable value) {
  final StatusView status = value as StatusView;
  return StatusView(
    serverAddress: status.serverAddress,
    serverReachable: status.serverReachable,
    hostedServerAddress: status.hostedServerAddress,
    deviceId: status.deviceId,
    account: status.account,
    pendingJoin: status.pendingJoin,
    peer: status.peer,
    rendezvousProblem: status.rendezvousProblem,
    runnerSettings: status.runnerSettings,
    appServers: status.appServers,
  );
}

JsonEncodable _rebuildAgentLoginStatusView(JsonEncodable value) {
  final AgentLoginStatusView status = value as AgentLoginStatusView;
  return AgentLoginStatusView(
    claudeLogin: status.claudeLogin,
    containerCredential: status.containerCredential,
  );
}

JsonEncodable _rebuildAuditEntryView(JsonEncodable value) {
  final AuditEntryView entry = value as AuditEntryView;
  return AuditEntryView(
    index: entry.index,
    at: entry.at,
    deviceId: entry.deviceId,
    event: entry.event,
    detail: entry.detail,
    previousHash: entry.previousHash,
    hash: entry.hash,
  );
}

JsonEncodable _rebuildJoiningDevice(JsonEncodable value) {
  final JoiningDevice device = value as JoiningDevice;
  return JoiningDevice(
    name: device.name,
    role: device.role,
    kind: device.kind,
    keyKind: device.keyKind,
    sealingPublicKey: device.sealingPublicKey,
    fingerprintWords: device.fingerprintWords,
  );
}

JsonEncodable _rebuildPairingRequestScreen(JsonEncodable value) {
  final PairingRequestScreen screen = value as PairingRequestScreen;
  return PairingRequestScreen(
    code: screen.code,
    displayCode: screen.displayCode,
    startedAt: screen.startedAt,
    expiresAt: screen.expiresAt,
    joining: screen.joining,
  );
}

JsonEncodable _rebuildJoinStatusView(JsonEncodable value) {
  final JoinStatusView status = value as JoinStatusView;
  final List<String> words = status.fingerprintWords;
  return switch (status) {
    JoinWaiting() => JoinWaiting(fingerprintWords: words),
    JoinApproved(:final AccountSummary account) => JoinApproved(
      fingerprintWords: words,
      account: account,
    ),
    JoinRejected() => JoinRejected(fingerprintWords: words),
    JoinExpired() => JoinExpired(fingerprintWords: words),
  };
}

JsonEncodable _rebuildOpenPersonStep(JsonEncodable value) {
  final OpenPersonStep step = value as OpenPersonStep;
  return OpenPersonStep(
    runId: step.runId,
    taskId: step.taskId,
    workspaceId: step.workspaceId,
    stepName: step.stepName,
    question: step.question,
    choices: step.choices,
    askedAt: step.askedAt,
  );
}
