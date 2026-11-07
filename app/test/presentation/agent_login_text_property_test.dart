import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/agent_login_values.dart'
    as node;
import 'package:agent_orchestration/data/models/agent_login.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/node_backed/mapping/agent_login_mapping.dart';
import 'package:agent_orchestration/presentation/agent_login_text.dart';

import '../support/random_inputs.dart';

const String _unknownWireName = 'unknown';

AgentLoginStatus _randomUnknownStatus(Random random) {
  return AgentLoginStatus(
    claudeLogin: ClaudeLogin.unknown,
    containerCredential: random.nextBool()
        ? null
        : pickOne(random, AgentCredentialKind.values),
  );
}

node.AgentCredentialKind? _randomNodeCredential(Random random) {
  if (random.nextBool()) {
    return null;
  }
  return pickOne(random, node.AgentCredentialKind.values);
}

void main() {
  test('test_describe_agent_login_property_an_unknown_login_is_never_'
      'ready_on_this_computer', () {
    final Random random = seededRandom(71431);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentLoginStatus status = _randomUnknownStatus(random);

      final AgentLoginDescription description = describeAgentLogin(
        place: AgentPlace.localProcess,
        status: status,
      );

      expect(description.isReady, isFalse);
      expect(description.statusText, unknownLoginText);
      expect(description.detail.trim(), isNotEmpty);
    }
  });

  test('test_describe_agent_login_property_an_unknown_login_keeps_the_'
      'container_credential', () {
    final Random random = seededRandom(71432);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentLoginStatus status = _randomUnknownStatus(random);
      final AgentLoginStatus loggedOutStatus = AgentLoginStatus(
        claudeLogin: ClaudeLogin.notLoggedIn,
        containerCredential: status.containerCredential,
      );

      final AgentLoginDescription unknownDescription = describeAgentLogin(
        place: AgentPlace.container,
        status: status,
      );
      final AgentLoginDescription loggedOutDescription = describeAgentLogin(
        place: AgentPlace.container,
        status: loggedOutStatus,
      );

      expect(unknownDescription.statusText, loggedOutDescription.statusText);
      expect(unknownDescription.isReady, status.containerCredential != null);
    }
  });

  test('test_map_agent_login_status_from_node_property_an_unknown_login_'
      'survives_decoding', () {
    final Random random = seededRandom(71433);

    for (int i = 0; i < propertyIterations; i += 1) {
      final node.AgentCredentialKind? credential = _randomNodeCredential(
        random,
      );
      final Map<String, Object?> reply = <String, Object?>{
        'claude_login': _unknownWireName,
        'container_credential': credential?.wireName,
      };

      final AgentLoginStatus status = mapAgentLoginStatusFromNode(
        node.AgentLoginStatusView.fromJson(reply),
      );

      expect(status.claudeLogin, ClaudeLogin.unknown);
      expect(status.containerCredential == null, credential == null);
    }
  });
}
