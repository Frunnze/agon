import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/approval_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart';

import '../../../support/random_inputs.dart';
import '../../support/hostile_texts.dart';

const int _largestRepositoryCount = 5;

const Map<AgentAccess, String> _rustAgentAccessNames = <AgentAccess, String>{
  AgentAccess.readOnly: 'read_only',
  AgentAccess.pushAfterApproval: 'push_after_approval',
};

const Map<ApprovalPolicy, String> _rustApprovalPolicyNames =
    <ApprovalPolicy, String>{
      ApprovalPolicy.askBeforeRiskyActions: 'ask_before_risky_actions',
      ApprovalPolicy.neverAsk: 'never_ask',
    };

Repository randomHostileRepository(Random random) {
  return Repository(
    address: randomHostileText(random),
    defaultBranch: randomHostileText(random),
    agentAccess: pickOne(random, AgentAccess.values),
  );
}

List<Repository> randomHostileRepositories(Random random) {
  final int repositoryCount = random.nextInt(_largestRepositoryCount);
  final List<Repository> repositories = <Repository>[];
  for (int i = 0; i < repositoryCount; i += 1) {
    repositories.add(randomHostileRepository(random));
  }
  return repositories;
}

ApprovalPolicy? randomChosenApprovalPolicy(Random random) {
  if (random.nextBool()) {
    return null;
  }
  return pickOne(random, ApprovalPolicy.values);
}

JsonObject expectedRepositoryJson(Repository repository) {
  return <String, Object?>{
    'address': repository.address,
    'default_branch': repository.defaultBranch,
    'agent_access': _rustAgentAccessNames[repository.agentAccess],
  };
}

List<Object?> expectedRepositoriesJson(List<Repository> repositories) {
  final List<Object?> repositoriesJson = <Object?>[];
  for (final Repository repository in repositories) {
    repositoriesJson.add(expectedRepositoryJson(repository));
  }
  return repositoriesJson;
}

String? expectedApprovalPolicyName(ApprovalPolicy? approvalPolicy) {
  if (approvalPolicy == null) {
    return null;
  }
  return _rustApprovalPolicyNames[approvalPolicy];
}
