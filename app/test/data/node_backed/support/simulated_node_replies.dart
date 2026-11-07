import 'dart:convert';

import 'package:agent_orchestration/bridge/node/node_command_channel.dart';

import '../../../bridge/support/scripted_node_transport.dart';

typedef SimulatedCommand = Map<String, Object?>;

typedef SimulatedHandler = Object? Function(SimulatedCommand command);

const String simulatedMoment = '2026-10-31T10:00:00Z';
const String simulatedOutageMessage = 'could not reach the app server: down';

final class SimulatedNodeFailure implements Exception {
  const SimulatedNodeFailure(this.message) : kind = null;

  const SimulatedNodeFailure.ofKind(this.message, {required String this.kind});

  final String message;
  final String? kind;
}

String _encodeSimulatedFailure(SimulatedNodeFailure failure) {
  final String? kind = failure.kind;
  if (kind == null) {
    return encodeErrorReply(failure.message);
  }
  return encodeKindedErrorReply(message: failure.message, kind: kind);
}

String answerSimulatedCommand({
  required String inputJson,
  required Map<String, SimulatedHandler> handlers,
  required Set<String> failingCommands,
}) {
  final SimulatedCommand command = jsonDecode(inputJson) as SimulatedCommand;
  final String name = command['command'] as String;
  final SimulatedHandler? handler = handlers[name];
  if (handler == null) {
    return encodeErrorReply('unknown command: $name');
  }
  if (failingCommands.contains(name)) {
    return encodeErrorReply(simulatedOutageMessage);
  }

  try {
    return encodeSuccessReply(handler(command));
  } on SimulatedNodeFailure catch (failure) {
    return _encodeSimulatedFailure(failure);
  }
}

NodeCommandChannel buildSimulatedChannel(NodeAnswer answer) {
  return NodeCommandChannel(transport: ScriptedNodeTransport(answer: answer));
}

Map<String, Object?> findSimulatedRecord(
  List<Map<String, Object?>> records, {
  required String kind,
  required Object? identifier,
}) {
  for (final Map<String, Object?> record in records) {
    if (record['id'] == identifier) {
      return record;
    }
  }
  throw SimulatedNodeFailure('$kind $identifier was not found');
}

Map<String, Object?> buildSimulatedDeviceJson({
  required String deviceId,
  required String name,
  required List<int> sealingPublicKey,
  required String? approvedBy,
}) {
  return <String, Object?>{
    'id': deviceId,
    'name': name,
    'role': 'client',
    'kind': 'computer',
    'key_kind': 'software',
    'signing_public_key': <int>[1, 2],
    'sealing_public_key': sealingPublicKey,
    'workspaces': <String>[],
    'paired_at': simulatedMoment,
    'approved_by': approvedBy,
    'last_seen': simulatedMoment,
    'revoked': false,
  };
}
