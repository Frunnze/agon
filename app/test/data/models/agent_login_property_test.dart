import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/agent_login_values.dart'
    as node;
import 'package:agent_orchestration/bridge/node/runner_settings.dart' as node;
import 'package:agent_orchestration/data/models/agent_login.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../bridge/support/list_copy_properties.dart';
import '../../support/random_inputs.dart';
import 'support/domain_model_properties.dart';

const List<AgentCredentialKind?> _possibleCredentials = <AgentCredentialKind?>[
  null,
  ...AgentCredentialKind.values,
];

LoginTerminal _buildLoginTerminal(ModelFieldValues fieldValues) {
  return LoginTerminal(
    place: fieldValues[0]! as AgentPlace,
    command: fieldValues[1]! as String,
    lines: fieldValues[2]! as List<String>,
    state: fieldValues[3]! as LoginTerminalState,
    problem: fieldValues[4] as String?,
  );
}

ModelFieldValues _randomLoginTerminalFields(Random random) {
  return <Object?>[
    pickOne(random, AgentPlace.values),
    randomHostileText(random),
    randomHostileTexts(random),
    pickOne(random, LoginTerminalState.values),
    if (random.nextBool()) null else randomHostileText(random),
  ];
}

ModelFieldValues _readLoginTerminalFields(LoginTerminal terminal) {
  return <Object?>[
    terminal.place,
    terminal.command,
    terminal.lines,
    terminal.state,
    terminal.problem,
  ];
}

ClaudeLogin _mapClaudeLoginThroughStatus(node.ClaudeLogin login) {
  final node.AgentLoginStatusView view = node.AgentLoginStatusView(
    claudeLogin: login,
    containerCredential: null,
  );
  return mapAgentLoginStatusFromNode(view).claudeLogin;
}

AgentCredentialKind _mapCredentialThroughStatus(
  node.AgentCredentialKind credential,
) {
  final node.AgentLoginStatusView view = node.AgentLoginStatusView(
    claudeLogin: node.ClaudeLogin.loggedIn,
    containerCredential: credential,
  );
  return mapAgentLoginStatusFromNode(view).containerCredential!;
}

LoginTerminalState _mapStateThroughTerminal(node.LoginState state) {
  final node.AgentLoginView view = node.AgentLoginView(
    place: node.AgentPlace.container,
    command: '',
    lines: const <String>[],
    state: state,
    problem: null,
  );
  return mapLoginTerminalFromNode(view).state;
}

void main() {
  testModelConstructorProperties(
    ModelConstructor<AgentLoginStatus>(
      testNamePrefix: 'test_agent_login_status_constructor_property',
      seed: 690101,
      randomFieldValues: (Random random) => <Object?>[
        pickOne(random, ClaudeLogin.values),
        pickOne(random, _possibleCredentials),
      ],
      construct: (ModelFieldValues fieldValues) => AgentLoginStatus(
        claudeLogin: fieldValues[0]! as ClaudeLogin,
        containerCredential: fieldValues[1] as AgentCredentialKind?,
      ),
      readFieldValues: (AgentLoginStatus status) => <Object?>[
        status.claudeLogin,
        status.containerCredential,
      ],
    ),
  );

  testModelConstructorProperties(
    const ModelConstructor<LoginTerminal>(
      testNamePrefix: 'test_login_terminal_constructor_property',
      seed: 690111,
      randomFieldValues: _randomLoginTerminalFields,
      construct: _buildLoginTerminal,
      readFieldValues: _readLoginTerminalFields,
    ),
  );

  testListCopyProperties(
    ListCopy<LoginTerminal, String>(
      testNamePrefix: 'test_login_terminal_constructor_property_lines',
      seed: 690121,
      buildElement: randomHostileText,
      construct: (Random random, List<String> lines) => LoginTerminal(
        place: pickOne(random, AgentPlace.values),
        command: randomHostileText(random),
        lines: lines,
        state: pickOne(random, LoginTerminalState.values),
        problem: null,
      ),
      readList: (LoginTerminal terminal) => terminal.lines,
    ),
  );

  testNodeEnumMappingProperties(
    const NodeEnumMapping<ClaudeLogin, node.ClaudeLogin>(
      testNamePrefix: 'test_claude_login_values_property',
      choices: ClaudeLogin.values,
      nodeChoices: node.ClaudeLogin.values,
      mapFromNode: _mapClaudeLoginThroughStatus,
    ),
  );

  testNodeEnumMappingProperties(
    const NodeEnumMapping<AgentCredentialKind, node.AgentCredentialKind>(
      testNamePrefix: 'test_agent_credential_kind_values_property',
      choices: AgentCredentialKind.values,
      nodeChoices: node.AgentCredentialKind.values,
      mapFromNode: _mapCredentialThroughStatus,
    ),
  );

  testNodeEnumMappingProperties(
    const NodeEnumMapping<LoginTerminalState, node.LoginState>(
      testNamePrefix: 'test_login_terminal_state_values_property',
      choices: LoginTerminalState.values,
      nodeChoices: node.LoginState.values,
      mapFromNode: _mapStateThroughTerminal,
    ),
  );
}
