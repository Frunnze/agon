import 'dart:math';

import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/models/agent_login.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../../support/random_inputs.dart';
import '../../fakes/support/agent_login_inputs.dart';
import '../../fakes/support/notification_counter.dart';
import 'held_next_reply_transport.dart';
import 'simulated_agent_login_node.dart';

const Duration quickLoginPolling = Duration(milliseconds: 1);
const Duration slowLoginPolling = Duration(hours: 1);
const Duration _waitStep = Duration(milliseconds: 1);
const Duration _waitLimit = Duration(seconds: 5);
const Map<ClaudeLogin, String> nodeClaudeLogins = <ClaudeLogin, String>{
  ClaudeLogin.loggedIn: 'logged_in',
  ClaudeLogin.notLoggedIn: 'not_logged_in',
  ClaudeLogin.notInstalled: 'not_installed',
  ClaudeLogin.unknown: 'unknown',
};
const Map<AgentCredentialKind, String> nodeCredentials =
    <AgentCredentialKind, String>{
      AgentCredentialKind.longLivedToken: 'long_lived_token',
      AgentCredentialKind.apiKey: 'api_key',
    };

typedef AgentLoginRig = ({
  SimulatedAgentLoginNode node,
  HeldNextReplyTransport transport,
  NodeBackedAgentLoginRepository repository,
  NotificationCounter notifications,
});

AgentLoginRig buildAgentLoginRig({required Duration pollInterval}) {
  final SimulatedAgentLoginNode simulated = SimulatedAgentLoginNode();
  final HeldNextReplyTransport transport = HeldNextReplyTransport(
    answer: simulated.answer,
  );
  final NodeBackedAgentLoginRepository repository =
      NodeBackedAgentLoginRepository(
        channel: NodeCommandChannel(transport: transport),
        pollInterval: pollInterval,
      );
  final NotificationCounter notifications = NotificationCounter();
  repository.addListener(notifications.record);
  return (
    node: simulated,
    transport: transport,
    repository: repository,
    notifications: notifications,
  );
}

void seedNodeLoginStatus(
  SimulatedAgentLoginNode simulated,
  AgentLoginStatus status,
) {
  simulated.claudeLogin = nodeClaudeLogins[status.claudeLogin]!;
  simulated.containerCredential = nodeCredentials[status.containerCredential];
}

int countReceivedCommands(SimulatedAgentLoginNode simulated, String name) {
  int count = 0;
  for (final String received in simulated.receivedCommands) {
    if (received == name) {
      count += 1;
    }
  }
  return count;
}

Future<void> waitForLogin(bool Function() isReached) async {
  final DateTime deadline = DateTime.now().add(_waitLimit);
  while (!isReached()) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('the login repository never caught up with the node');
    }
    await Future<void>.delayed(_waitStep);
  }
}

const List<String> _blankKeys = <String>['', ' ', '\t\n', '\u3000', '\r\n '];
const List<String> _breakingParts = <String>[' ', '\n', '\t', '\u0007'];

String randomRefusedApiKey(Random random) {
  if (random.nextBool()) {
    return pickOne(random, _blankKeys);
  }
  final String breakingPart = pickOne(random, _breakingParts);
  final String apiKey = 'key$breakingPart${randomValidApiKey(random)}';
  return apiKey.trimRight();
}

Future<AgentLoginRig> buildCheckedAgentLoginRig(
  AgentLoginStatus status,
) async {
  final AgentLoginRig rig = buildAgentLoginRig(pollInterval: slowLoginPolling);
  seedNodeLoginStatus(rig.node, status);
  await rig.repository.checkStatus();
  return rig;
}
