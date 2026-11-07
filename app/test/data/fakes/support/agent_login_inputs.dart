import 'dart:math';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/agent_login.dart';
import 'package:agent_orchestration/data/models/runner.dart';

import '../../../support/random_inputs.dart';
import 'notification_counter.dart';

const String enterKey = '\r';
const Map<AgentPlace, String> nodeLoginCommands = <AgentPlace, String>{
  AgentPlace.container: 'claude setup-token',
  AgentPlace.localProcess: 'claude auth login',
};
const List<String> _keyCharacters = <String>[
  'a',
  'Z',
  '0',
  '-',
  '_',
  '.',
  'é',
  '\u{1F511}',
];
const List<String> _paddings = <String>['', ' ', '\t', '\n', '\r\n', '\u3000'];
const int _longestKey = 24;

typedef CountedRepository = ({
  FakeAgentLoginRepository repository,
  NotificationCounter notifications,
});

AgentLoginStatus randomKnownAgentLoginStatus(Random random) {
  final List<AgentCredentialKind?> credentials = <AgentCredentialKind?>[
    null,
    ...AgentCredentialKind.values,
  ];
  return AgentLoginStatus(
    claudeLogin: pickOne(random, ClaudeLogin.values),
    containerCredential: pickOne(random, credentials),
  );
}

AgentLoginStatus? randomAgentLoginStatus(Random random) {
  if (random.nextInt(4) == 0) {
    return null;
  }
  return randomKnownAgentLoginStatus(random);
}

String randomValidApiKey(Random random) {
  final StringBuffer key = StringBuffer(pickOne(random, _paddings));
  final int length = 1 + random.nextInt(_longestKey);
  for (int i = 0; i < length; i += 1) {
    key.write(pickOne(random, _keyCharacters));
  }
  key.write(pickOne(random, _paddings));
  return key.toString();
}

CountedRepository buildCountedRepository(AgentLoginStatus? status) {
  final FakeAgentLoginRepository repository = FakeAgentLoginRepository(
    status: status,
  );
  final NotificationCounter notifications = NotificationCounter();
  repository.addListener(notifications.record);
  return (repository: repository, notifications: notifications);
}
