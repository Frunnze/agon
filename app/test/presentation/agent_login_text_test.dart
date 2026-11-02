import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/agent_login.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/presentation/agent_login_text.dart';

import '../support/random_inputs.dart';

const List<String> _loginFailures = <String>[
  'Not logged in · Please run /login',
  'Invalid API key · Please run /login',
  'the drafting run did not finish: Not logged in · Please run /login',
];

AgentLoginStatus _randomStatus(Random random) {
  return AgentLoginStatus(
    claudeLogin: pickOne(random, ClaudeLogin.values),
    containerCredential: random.nextBool()
        ? null
        : pickOne(random, AgentCredentialKind.values),
  );
}

List<AgentLoginAction> _expectedActions(
  AgentPlace place,
  AgentLoginStatus status,
) {
  if (place == AgentPlace.localProcess) {
    if (status.claudeLogin == ClaudeLogin.notLoggedIn) {
      return <AgentLoginAction>[AgentLoginAction.logIn];
    }
    return <AgentLoginAction>[];
  }
  if (status.containerCredential != null) {
    return <AgentLoginAction>[AgentLoginAction.disconnect];
  }
  if (status.claudeLogin == ClaudeLogin.notInstalled) {
    return <AgentLoginAction>[AgentLoginAction.useApiKey];
  }
  return <AgentLoginAction>[
    AgentLoginAction.connect,
    AgentLoginAction.useApiKey,
  ];
}

void main() {
  test('test_is_agent_login_problem_property_spots_login_failures', () {
    final Random random = seededRandom(9501);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String reason =
          '${randomText(random)}${pickOne(random, _loginFailures)}'
          '${randomText(random)}';

      expect(isAgentLoginProblem(reason), isTrue, reason: reason);
    }
  });

  test('test_is_agent_login_problem_property_other_failures_are_not', () {
    final Random random = seededRandom(9502);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String reason = randomWordPhrase(random);

      expect(isAgentLoginProblem(reason), isFalse, reason: reason);
    }
  });

  test('test_describe_agent_login_property_every_status_is_explained', () {
    final Random random = seededRandom(9503);
    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentPlace place = pickOne(random, AgentPlace.values);
      final AgentLoginStatus status = _randomStatus(random);

      final AgentLoginDescription description = describeAgentLogin(
        place: place,
        status: status,
      );

      expect(description.statusText.trim(), isNotEmpty);
      expect(description.detail.trim(), isNotEmpty);
      final bool isReady = place == AgentPlace.localProcess
          ? status.claudeLogin == ClaudeLogin.loggedIn
          : status.containerCredential != null;
      expect(description.isReady, isReady);
    }
  });

  test('test_choose_agent_login_actions_property_offer_the_next_step', () {
    final Random random = seededRandom(9504);
    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentPlace place = pickOne(random, AgentPlace.values);
      final AgentLoginStatus status = _randomStatus(random);

      final List<AgentLoginAction> actions = chooseAgentLoginActions(
        place: place,
        status: status,
      );

      expect(actions, _expectedActions(place, status));
    }
  });

  test('test_describe_other_runner_login_hint_property_names_it', () {
    final Random random = seededRandom(9505);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String runnerName = 'runner-${randomText(random)}';

      final String hint = describeOtherRunnerLoginHint(runnerName);

      expect(hint, contains(runnerName));
      expect(hint, isNot(thisComputerLoginHint));
    }
  });
}
