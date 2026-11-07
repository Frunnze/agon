import 'dart:math';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../../support/fake_task_work_links.dart';
import '../../../support/random_inputs.dart';
import '../../../support/sample_scopes.dart';
import 'notification_counter.dart';

const String createdRulePrefix = 'created-rule-';
const WorkspaceId ruleWorkspaceId = GalleryWorkspaceIds.acme;
const int _largestSeededRuleCount = 6;

typedef CountedRules = ({
  FakeRuleRepository repository,
  NotificationCounter notifications,
  List<Rule> seeded,
  DateTime now,
});

Rule randomRuleWithId(Random random, RuleId id) {
  return Rule(
    id: id,
    title: 'Rule ${randomWordPhrase(random)}',
    details: randomText(random),
    scope: randomScopeInRuleWorkspace(random),
    enabled: random.nextBool(),
    addedAt: randomUtcMoment(random),
  );
}

List<Rule> randomSeededRules(Random random) {
  final int count = random.nextInt(_largestSeededRuleCount);
  return <Rule>[
    for (int i = 0; i < count; i += 1)
      randomRuleWithId(random, RuleId('rule-$i')),
  ];
}

Scope randomScopeInRuleWorkspace(Random random) {
  final Scope scope = randomScope(random);
  final WorkspaceScope workspaces = scope.workspaces;
  if (workspaces is! OnlyWorkspaces) {
    return scope;
  }
  if (workspaces.workspaces.contains(ruleWorkspaceId)) {
    return scope;
  }

  final List<WorkspaceId> widened = <WorkspaceId>[
    ...workspaces.workspaces,
    ruleWorkspaceId,
  ];
  return Scope(workspaces: OnlyWorkspaces(widened), projects: scope.projects);
}

RuleDraft randomRuleDraft(Random random) {
  return RuleDraft(
    title: 'Keep ${randomWordPhrase(random)}',
    details: randomText(random),
    scope: randomScopeInRuleWorkspace(random),
  );
}

CountedRules buildCountedRules(Random random, List<Rule> seeded) {
  final DateTime now = randomUtcMoment(random);
  final FakeRuleRepository repository = FakeRuleRepository(
    rules: seeded,
    clock: FixedClock(now),
    workspaceRepository: buildAcmeWorkspaceRepository(),
  );
  final NotificationCounter notifications = NotificationCounter();
  repository.addListener(notifications.record);
  return (
    repository: repository,
    notifications: notifications,
    seeded: seeded,
    now: now,
  );
}

RuleId randomMissingRuleId(Random random) {
  return RuleId('rule-missing-${randomText(random)}');
}

String describeScope(Scope scope) {
  return mapScopeToNode(scope).toJson().toString();
}

String describeRuleContent(Rule rule) {
  return '${rule.title} ${rule.details} ${rule.enabled} '
      '${describeScope(rule.scope)}';
}

List<RuleId> listRuleIds(FakeRuleRepository repository) {
  return <RuleId>[for (final Rule rule in repository.listRules()) rule.id];
}
