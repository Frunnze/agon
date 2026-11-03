import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes/gallery_dependencies.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/presentation/agent_place_text.dart';
import 'package:agent_orchestration/screens/new_items/draft_review.dart';
import 'package:agent_orchestration/screens/new_items/library_draft_reviews.dart';
import 'package:agent_orchestration/screens/new_items/project_draft_review.dart';
import 'package:agent_orchestration/screens/projects/agent_access_choices.dart';
import 'package:agent_orchestration/screens/new_items/work_draft_review.dart';
import 'package:agent_orchestration/screens/shared/muted_note.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/fact_list.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

import '../../support/random_inputs.dart';

const ProjectId _unknownProjectId = ProjectId('project-nowhere');
const WorkflowId _unknownWorkflowId = WorkflowId('workflow-nowhere');
const List<String> _taskTerms = <String>[
  'What should be done',
  'Details',
  'Project',
  'Who does it',
  'Runs on',
  'Where agents run',
  'Skills to use',
  'Automatic skills',
  'Commands',
];

String _readFactText(Fact fact) {
  final Object? content = fact.content;
  if (content is MutedNote) {
    return content.text;
  }
  if (fact.chips.isNotEmpty) {
    return fact.chips.join(', ');
  }
  return <String>[
    for (final TextSegment segment in fact.description) segment.text,
  ].join();
}

Fact _findFact(List<Fact> facts, String term) {
  return facts.firstWhere((Fact fact) => fact.term == term);
}

WorkDraftReview _buildWorkReview(
  AppDependencies dependencies,
  DraftKind kind,
) {
  return WorkDraftReview(
    kind: kind,
    projectRepository: dependencies.projectRepository,
    workspaceRepository: dependencies.workspaceRepository,
    workflowRepository: dependencies.workflowRepository,
    skillRepository: dependencies.skillRepository,
    deviceRepository: dependencies.deviceRepository,
    taskRepository: dependencies.taskRepository,
    jobRepository: dependencies.jobRepository,
    navigation: AppNavigation(
      initialRoute: const SectionRoute(AppSection.tasks),
    ),
  );
}

DraftedWork _randomWork(Random random) {
  return DraftedWork(
    title: 'Title ${randomText(random)}',
    details: randomWordPhrase(random),
    projectId: pickOne(random, <ProjectId?>[
      GalleryProjectIds.acmeApp,
      null,
      _unknownProjectId,
    ]),
    doer: pickOne(random, <TaskDoer>[
      const OneAgentDoer(AgentKind.codex),
      const WorkflowDoer(GalleryWorkflowIds.release),
      const WorkflowDoer(_unknownWorkflowId),
    ]),
    runsOn: pickOne(random, <RunnerTarget>[
      const AnyFreeRunner(),
      const SpecificRunner(GalleryDeviceIds.macStudio),
      const SpecificRunner(DeviceId('device-nowhere')),
    ]),
    agentPlace: pickOne(random, AgentPlace.values),
    skills: random.nextBool()
        ? const <SkillId>[]
        : const <SkillId>[GallerySkillIds.gitCleanup],
    usesAutomaticSkills: random.nextBool(),
    approvalPolicy: pickOne(random, ApprovalPolicy.values),
    schedule: random.nextBool() ? null : HourlySchedule(minute: 5),
  );
}

void main() {
  test('test_describe_facts_property_work_drafts_show_every_field', () {
    final Random random = seededRandom(8501);
    final AppDependencies dependencies = buildGalleryDependencies();

    for (int i = 0; i < propertyIterations; i += 1) {
      final DraftKind kind = pickOne(random, <DraftKind>[
        DraftKind.task,
        DraftKind.job,
      ]);
      final DraftedWork work = _randomWork(random);

      final List<Fact> facts = _buildWorkReview(
        dependencies,
        kind,
      ).describeFacts(work);

      final List<String> terms = <String>[
        for (final Fact fact in facts) fact.term,
      ];
      expect(terms.sublist(0, _taskTerms.length), _taskTerms);
      expect(
        _readFactText(_findFact(facts, 'What should be done')),
        work.title,
      );
      final String project = _readFactText(_findFact(facts, 'Project'));
      final String expectedProject = switch (work.projectId) {
        null => notChosenText,
        GalleryProjectIds.acmeApp => 'acme-app',
        _ => unknownProjectText,
      };
      expect(project, expectedProject);
      expect(
        _readFactText(_findFact(facts, agentPlaceTitle)),
        describeTaskPlace(work.agentPlace),
      );
      final bool repeats = work.schedule != null || kind == DraftKind.job;
      expect(terms.last, repeats ? 'Repeats' : 'Starts');
    }
  });

  test('test_describe_facts_property_project_drafts_list_their_repos', () {
    final Random random = seededRandom(8502);
    final AppDependencies dependencies = buildGalleryDependencies();
    final ProjectDraftReview review = ProjectDraftReview(
      projectRepository: dependencies.projectRepository,
      workspaceRepository: dependencies.workspaceRepository,
      deviceRepository: dependencies.deviceRepository,
      navigation: AppNavigation(
        initialRoute: const SectionRoute(AppSection.projects),
      ),
    );

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<RepositoryDraft> repositories = <RepositoryDraft>[
        for (int j = 0; j < random.nextInt(3); j += 1)
          RepositoryDraft(
            address: 'github.com/acme/app$j',
            defaultBranch: 'main',
          ),
      ];
      final DraftedProject project = DraftedProject(
        name: 'billing',
        repositories: repositories,
        agentAccess: pickOne(random, AgentAccess.values),
      );

      final List<Fact> facts = review.describeFacts(project);

      final Fact repos = _findFact(facts, 'Repos');
      expect(repos.content is MutedNote, repositories.isEmpty);
      expect(
        _readFactText(_findFact(facts, 'What agents can do')),
        describeAgentAccessChoiceTitle(project.agentAccess),
      );
    }
  });

  test('test_describe_draft_scope_chips_property_unknown_ids_are_named', () {
    final Random random = seededRandom(8503);
    final AppDependencies dependencies = buildGalleryDependencies();
    final RuleDraftReview review = RuleDraftReview(
      ruleRepository: dependencies.ruleRepository,
      workspaceRepository: dependencies.workspaceRepository,
      projectRepository: dependencies.projectRepository,
      navigation: AppNavigation(
        initialRoute: const SectionRoute(AppSection.rules),
      ),
    );

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<ProjectId> projectIds = <ProjectId>[
        for (int j = 0; j < random.nextInt(3); j += 1)
          pickOne(random, <ProjectId>[
            GalleryProjectIds.docs,
            _unknownProjectId,
          ]),
      ];
      final RuleDraft rule = RuleDraft(
        title: 'Keep commits small',
        details: '',
        scope: Scope(
          workspaces: const AllWorkspaces(),
          projects: OnlyProjects(projectIds),
        ),
      );

      final List<Fact> facts = review.describeFacts(DraftedRule(rule));

      final List<String> chips = _findFact(facts, 'Applies to').chips;
      final List<String> expected = <String>[
        for (final ProjectId projectId in projectIds)
          if (projectId == _unknownProjectId) unknownProjectChip else 'docs',
      ];
      expect(chips, expected.isEmpty ? <String>[everywhereChip] : expected);
      expect(_readFactText(_findFact(facts, 'Details')), noneChosenText);
    }
  });

  test('a review refuses a draft of another kind', () {
    final AppDependencies dependencies = buildGalleryDependencies();
    final DraftReview review = SkillDraftReview(
      skillRepository: dependencies.skillRepository,
      workspaceRepository: dependencies.workspaceRepository,
      projectRepository: dependencies.projectRepository,
      navigation: AppNavigation(
        initialRoute: const SectionRoute(AppSection.skills),
      ),
    );
    const DraftedRule rule = DraftedRule(
      RuleDraft(title: 'x', details: '', scope: Scope.everywhere()),
    );

    expect(() => review.describeFacts(rule), throwsArgumentError);
  });
}
