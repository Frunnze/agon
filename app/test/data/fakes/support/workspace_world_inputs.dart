import 'dart:math';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/fakes/fake_task_work.dart';
import 'package:agent_orchestration/data/fakes/fake_workspace_contents.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workspace.dart';

import '../../../support/fake_task_work_links.dart';
import '../../../support/random_inputs.dart';
import 'project_work_inputs.dart';
import 'skill_inputs.dart';
import 'workflow_inputs.dart';
import 'workspace_inputs.dart';

const int worldWorkspaceCount = 3;
const WorkspaceId unknownWorldWorkspaceId = WorkspaceId('never-a-workspace');
const int _largestLibraryCount = 5;

typedef WorkspaceWorld = ({
  ProjectWorkSeed work,
  List<Project> projects,
  List<Rule> rules,
  List<Skill> skills,
  List<Workflow> workflows,
  FakeTaskRepository taskRepository,
  FakeProjectRepository projectRepository,
  FakeSkillRepository skillRepository,
  FakeRuleRepository ruleRepository,
  FakeWorkflowRepository workflowRepository,
  FakeWorkspaceRepository workspaceRepository,
  FakeWorkspaceContents contents,
});

List<WorkspaceId> listWorldWorkspaceIds(FakeWorkspaceRepository repository) {
  return <WorkspaceId>[
    for (final Workspace workspace in repository.listWorkspaces())
      workspace.id,
  ];
}

WorkspaceScope randomWorldWorkspaceScope(Random random) {
  if (random.nextInt(3) == 0) {
    return const AllWorkspaces();
  }
  final List<WorkspaceId> listed = <WorkspaceId>[];
  for (int index = 0; index < worldWorkspaceCount; index += 1) {
    if (random.nextBool()) {
      listed.add(WorkspaceId('seeded-workspace-$index'));
    }
  }
  if (random.nextInt(4) == 0) {
    listed.add(unknownWorldWorkspaceId);
  }
  return OnlyWorkspaces(listed);
}

Scope _randomWorldScope(Random random) {
  return Scope(
    workspaces: randomWorldWorkspaceScope(random),
    projects: const AllProjects(),
  );
}

List<Rule> _randomRules(Random random) {
  final int count = random.nextInt(_largestLibraryCount + 1);
  return <Rule>[
    for (int index = 0; index < count; index += 1)
      Rule(
        id: RuleId('world-rule-$index'),
        title: 'Rule $index',
        details: randomText(random),
        scope: _randomWorldScope(random),
        enabled: random.nextBool(),
        addedAt: randomUtcMoment(random),
      ),
  ];
}

List<Skill> _randomSkills(Random random) {
  final int count = random.nextInt(_largestLibraryCount + 1);
  final List<Skill> skills = <Skill>[];
  for (int index = 0; index < count; index += 1) {
    final Skill seeded = randomSeededSkill(random, index);
    skills.add(
      Skill(
        id: seeded.id,
        name: seeded.name,
        summary: seeded.summary,
        instructions: seeded.instructions,
        scope: _randomWorldScope(random),
        usage: seeded.usage,
        source: seeded.source,
        improvement: seeded.improvement,
        history: seeded.history,
      ),
    );
  }
  return skills;
}

List<Workflow> _randomWorkflows(Random random) {
  final List<Workflow> workflows = <Workflow>[];
  for (int index = 0; index < workWorkflowIds.length; index += 1) {
    final Workflow graph = randomValidWorkflow(
      random,
      index: index,
      signature: null,
    );
    workflows.add(
      Workflow(
        id: workWorkflowIds[index],
        name: graph.name,
        availability: randomWorldWorkspaceScope(random),
        agents: graph.agents,
        connections: graph.connections,
        signature: null,
      ),
    );
  }
  return workflows;
}

List<Project> _randomProjects(Random random) {
  return <Project>[
    for (final ProjectId projectId in workProjectIds)
      Project(
        id: projectId,
        workspaceId: WorkspaceId(
          'seeded-workspace-${random.nextInt(worldWorkspaceCount)}',
        ),
        name: 'name-${projectId.value}',
        repositories: const <Repository>[],
        approvalPolicy: null,
      ),
  ];
}

FakeWorkspaceRepository _buildWorkspaces(Random random) {
  final List<Workspace> workspaces = <Workspace>[
    for (int index = 0; index < worldWorkspaceCount; index += 1)
      buildSampleWorkspace(random, index),
  ];
  return buildWorkspaceRepository(
    workspaces: workspaces,
    currentWorkspaceId: pickOne(random, workspaces).id,
    appServerGroup: randomAppServerGroup(random),
  );
}

WorkspaceWorld buildWorkspaceWorld(Random random) {
  final ProjectWorkSeed work = randomProjectWork(random);
  final List<Project> projects = _randomProjects(random);
  final List<Rule> rules = _randomRules(random);
  final List<Skill> skills = _randomSkills(random);
  final List<Workflow> workflows = _randomWorkflows(random);
  final FakeTaskRepository taskRepository = buildProjectWorkRepository(work);
  final FakeTaskWork taskWork = buildTaskWorkOver(taskRepository);
  final FakeWorkflowRepository workflowRepository = buildWorkflowRepository(
    workflows: workflows,
    changes: const <WorkflowChange>[],
  );
  workflowRepository.linkWork(
    taskWork: taskWork,
    approvalRepository: FakeApprovalRepository(
      approvals: const <ApprovalRequest>[],
      clock: FixedClock(galleryNow),
      currentDeviceId: GalleryDeviceIds.airLaptop,
    ),
  );
  final FakeProjectRepository projectRepository = FakeProjectRepository(
    projects: projects,
    taskWork: taskWork,
  );
  final FakeWorkspaceRepository workspaceRepository = _buildWorkspaces(random);
  final FakeSkillRepository skillRepository = buildSkillRepository(skills);
  final FakeRuleRepository ruleRepository = FakeRuleRepository(
    rules: rules,
    clock: FixedClock(galleryNow),
    workspaceRepository: workspaceRepository,
  );
  final FakeWorkspaceContents contents = FakeWorkspaceContents(
    projectRepository: projectRepository,
    taskWork: taskWork,
    skillRepository: skillRepository,
    ruleRepository: ruleRepository,
    workflowRepository: workflowRepository,
  );
  workspaceRepository.linkContents(contents);
  return (
    work: work,
    projects: projects,
    rules: rules,
    skills: skills,
    workflows: workflows,
    taskRepository: taskRepository,
    projectRepository: projectRepository,
    skillRepository: skillRepository,
    ruleRepository: ruleRepository,
    workflowRepository: workflowRepository,
    workspaceRepository: workspaceRepository,
    contents: contents,
  );
}

Set<ProjectId> listWorldProjectsIn(
  WorkspaceWorld world,
  WorkspaceId workspaceId,
) {
  return <ProjectId>{
    for (final Project project in world.projects)
      if (project.workspaceId == workspaceId) project.id,
  };
}

Set<WorkspaceId> listOtherWorkspaceIds(
  WorkspaceWorld world,
  WorkspaceId deleted,
) {
  return <WorkspaceId>{
    for (final WorkspaceId workspaceId in listWorldWorkspaceIds(
      world.workspaceRepository,
    ))
      if (workspaceId != deleted) workspaceId,
  };
}

typedef WorldWithIdle = ({WorkspaceWorld world, Workspace idle});

WorldWithIdle buildWorldWithIdleWorkspace(Random random) {
  final WorkspaceWorld world = buildWorkspaceWorld(random);
  for (final Workspace workspace
      in world.workspaceRepository.listWorkspaces()) {
    final Set<ProjectId> projectIds = listWorldProjectsIn(world, workspace.id);
    if (!isRunningLikeServer(world.work, projectIds)) {
      return (world: world, idle: workspace);
    }
  }
  return buildWorldWithIdleWorkspace(random);
}
