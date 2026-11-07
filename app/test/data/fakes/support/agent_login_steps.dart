import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/agent_login.dart';
import 'package:agent_orchestration/data/models/runner.dart';

import '../../../support/random_inputs.dart';
import 'agent_login_inputs.dart';
import 'refusals.dart';

const int _longestSequence = 8;
const int _longestTyping = 6;

enum _LoginStep { open, type, close, saveKey, forget, finish, fail, check }

Future<void> _attempt(Future<void> Function() step) async {
  await isRefused(step, isRefusal: refusesWithStateError);
}

Future<void> _runRandomStep(
  Random random,
  FakeAgentLoginRepository repository,
) async {
  final _LoginStep step = pickOne(random, _LoginStep.values);
  switch (step) {
    case _LoginStep.open:
      final AgentPlace place = pickOne(random, AgentPlace.values);
      await _attempt(() => repository.openTerminal(place));
    case _LoginStep.type:
      final String keys = '${randomText(random)}$enterKey';
      await _attempt(() => repository.typeIntoTerminal(keys));
    case _LoginStep.close:
      await repository.closeTerminal();
    case _LoginStep.saveKey:
      await repository.saveApiKey(randomValidApiKey(random));
    case _LoginStep.forget:
      await repository.forgetCredential();
    case _LoginStep.finish:
      await _attempt(() async => repository.endTerminal(problem: null));
    case _LoginStep.fail:
      final String problem = randomText(random);
      await _attempt(() async => repository.endTerminal(problem: problem));
    case _LoginStep.check:
      await repository.checkStatus();
  }
}

Future<void> runRandomLoginSteps(
  Random random,
  FakeAgentLoginRepository repository,
) async {
  final int count = random.nextInt(_longestSequence);
  for (int i = 0; i < count; i += 1) {
    await _runRandomStep(random, repository);
  }
}

Future<void> typeRandomLoginLines(
  Random random,
  FakeAgentLoginRepository repository,
) async {
  final int typingCount = random.nextInt(_longestTyping);
  for (int typing = 0; typing < typingCount; typing += 1) {
    await repository.typeIntoTerminal('${randomText(random)}$enterKey');
  }
}

Future<FakeAgentLoginRepository> buildRepositoryWithFailedLogin(
  Random random,
) async {
  final FakeAgentLoginRepository repository = FakeAgentLoginRepository(
    status: randomAgentLoginStatus(random),
  );
  await repository.openTerminal(pickOne(random, AgentPlace.values));
  repository.endTerminal(problem: randomText(random));
  return repository;
}

void expectSameLoginStatus(
  AgentLoginStatus? actual,
  AgentLoginStatus? expected,
) {
  expect(actual?.claudeLogin, expected?.claudeLogin);
  expect(actual?.containerCredential, expected?.containerCredential);
}
