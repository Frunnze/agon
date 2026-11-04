import 'dart:math';

import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';

import '../../support/random_inputs.dart';
import '../../support/random_schedules.dart';
import '../../support/sample_records.dart';
import '../../support/sample_scopes.dart';

const List<String> _branches = <String>['main', 'develop', 'release/2.4'];
const int _mostDraftedRepositories = 3;

String _randomSentence(Random random, String firstWord) {
  return '$firstWord ${randomWordPhrase(random)}'.trim();
}

List<T> _pickSomeOrOne<T>(Random random, List<T> choices) {
  final List<T> picked = pickSome(random, choices);
  if (picked.isEmpty) {
    return <T>[pickOne(random, choices)];
  }
  return picked;
}

Scope _randomValidScope(Random random) {
  final WorkspaceScope workspaces = random.nextBool()
      ? const AllWorkspaces()
      : OnlyWorkspaces(_pickSomeOrOne(random, sampleWorkspaceIds));
  final ProjectScope projects = random.nextBool()
      ? const AllProjects()
      : OnlyProjects(_pickSomeOrOne(random, sampleProjectIds));

  return Scope(workspaces: workspaces, projects: projects);
}

DraftedWork randomListedWork(Random random, DraftKind kind) {
  final bool repeats = kind == DraftKind.job || random.nextBool();

  return DraftedWork(
    title: _randomSentence(random, 'Ship'),
    details: randomWordPhrase(random).trim(),
    projectId: pickOne(random, sampleProjectIds),
    doer: pickOne(random, <TaskDoer>[
      for (final AgentKind agent in AgentKind.values) OneAgentDoer(agent),
      const WorkflowDoer(GalleryWorkflowIds.release),
    ]),
    runsOn: pickOne(random, <RunnerTarget>[
      const AnyFreeRunner(),
      const SpecificRunner(GalleryDeviceIds.macStudio),
    ]),
    agentPlace: pickOne(random, AgentPlace.values),
    skills: pickSome(random, <SkillId>[
      GallerySkillIds.gitCleanup,
      GallerySkillIds.writeTests,
    ]),
    usesAutomaticSkills: random.nextBool(),
    approvalPolicy: randomInheritableApprovalPolicy(random),
    schedule: repeats ? randomSchedule(random) : null,
  );
}

DraftedProject _randomProject(Random random, int round) {
  final int repositoryCount = 1 + random.nextInt(_mostDraftedRepositories);

  return DraftedProject(
    name: 'drafted-project-$round',
    repositories: <RepositoryDraft>[
      for (int j = 0; j < repositoryCount; j += 1)
        RepositoryDraft(
          address: 'github.com/acme/drafted-$round-$j',
          defaultBranch: pickOne(random, _branches),
        ),
    ],
    agentAccess: pickOne(random, AgentAccess.values),
    approvalPolicy: randomInheritableApprovalPolicy(random),
  );
}

DraftedSkill _randomSkill(Random random, int round) {
  return DraftedSkill(
    SkillDraft(
      name: 'drafted-skill-$round',
      summary: _randomSentence(random, 'Write'),
      instructions:
          '${_randomSentence(random, 'List')}\n'
          '${randomWordPhrase(random)}',
      scope: _randomValidScope(random),
      usage: pickOne(random, SkillUsage.values),
      improvement: pickOne(random, SkillImprovement.values),
    ),
  );
}

DraftedRule _randomRule(Random random) {
  return DraftedRule(
    RuleDraft(
      title: _randomSentence(random, 'Keep'),
      details: randomWordPhrase(random).trim(),
      scope: _randomValidScope(random),
    ),
  );
}

DraftedItem randomDraftedItem(Random random, DraftKind kind, int round) {
  return switch (kind) {
    DraftKind.task || DraftKind.job => randomListedWork(random, kind),
    DraftKind.project => _randomProject(random, round),
    DraftKind.skill => _randomSkill(random, round),
    DraftKind.rule => _randomRule(random),
  };
}
