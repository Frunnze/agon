import 'dart:convert';
import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/library_values.dart' as node;
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../../bridge/support/node_wire_names.dart';
import '../../../support/random_inputs.dart';
import '../../../support/sample_records.dart';
import '../../node_backed/support/simulated_catalog_node.dart';
import '../../node_backed/support/simulated_work_node.dart';
import 'task_inputs.dart';
import 'workspace_scope_inputs.dart';

const ProjectId _neverMadeProjectId = ProjectId('project-never-made');
const int _largestProjectCount = 4;
const int _largestLibraryCount = 4;
const int _largestTaskCount = 6;
const int _largestRunsPerTask = 2;

typedef CatalogTwinSeeds = ({
  List<WorkspaceId> workspaceIds,
  List<Project> projects,
  List<Skill> skills,
  List<Rule> rules,
  List<Task> tasks,
  List<Run> runs,
});

Object? _encodeWire(Object? json) => jsonDecode(jsonEncode(json));

ProjectScope _randomProjectScope(Random random, List<Project> projects) {
  if (random.nextInt(3) == 0) {
    return const AllProjects();
  }
  return OnlyProjects(<ProjectId>[
    for (final Project project in projects)
      if (random.nextBool()) project.id,
    if (random.nextInt(4) == 0) _neverMadeProjectId,
  ]);
}

Scope _randomTwinScope(
  Random random,
  List<WorkspaceId> workspaceIds,
  List<Project> projects,
) {
  return Scope(
    workspaces: randomWorkspaceScopeOver(random, workspaceIds),
    projects: _randomProjectScope(random, projects),
  );
}

List<Project> _seedProjects(
  Random random,
  SimulatedCatalogNode simulated,
  List<WorkspaceId> workspaceIds,
) {
  final int count = 1 + random.nextInt(_largestProjectCount);
  final List<Project> projects = <Project>[];
  for (int index = 0; index < count; index += 1) {
    final Project project = Project(
      id: ProjectId(simulated.nextIdentifier('project')),
      workspaceId: pickOne(random, workspaceIds),
      name: 'project-$index',
      repositories: const <Repository>[],
      approvalPolicy: null,
    );
    simulated.projects.add(<String, Object?>{
      'id': project.id.value,
      'workspace_id': project.workspaceId.value,
      'name': project.name,
      'repositories': <Object?>[],
      'approval_policy': null,
    });
    projects.add(project);
  }
  return projects;
}

List<Skill> _seedSkills(
  Random random,
  SimulatedCatalogNode simulated,
  List<WorkspaceId> workspaceIds,
  List<Project> projects,
) {
  final int count = random.nextInt(_largestLibraryCount + 1);
  final List<Skill> skills = <Skill>[];
  for (int index = 0; index < count; index += 1) {
    final Map<String, Object?> wire = simulated.addSkill(
      workspaceId: pickOne(random, workspaceIds).value,
      name: 'skill-$index',
    );
    final Scope scope = _randomTwinScope(random, workspaceIds, projects);
    wire['scope'] = _encodeWire(mapScopeToNode(scope).toJson());
    skills.add(mapSkillFromNode(node.Skill.fromJson(_encodeWire(wire))));
  }
  return skills;
}

List<Rule> _seedRules(
  Random random,
  SimulatedCatalogNode simulated,
  List<WorkspaceId> workspaceIds,
  List<Project> projects,
) {
  final int count = random.nextInt(_largestLibraryCount + 1);
  final List<Rule> rules = <Rule>[];
  for (int index = 0; index < count; index += 1) {
    final Map<String, Object?> wire = simulated.addRule(
      workspaceId: pickOne(random, workspaceIds).value,
      title: 'Rule $index',
    );
    final Scope scope = _randomTwinScope(random, workspaceIds, projects);
    wire['scope'] = _encodeWire(mapScopeToNode(scope).toJson());
    rules.add(mapRuleFromNode(node.Rule.fromJson(_encodeWire(wire))));
  }
  return rules;
}

Task _buildTwinTask(
  Random random, {
  required int index,
  required ProjectId projectId,
  required List<SkillId> skills,
}) {
  final TaskDraft base = randomTaskDraft(random);
  return Task.fromDraft(
    id: TaskId('twin-task-$index'),
    draft: TaskDraft(
      title: base.title,
      details: base.details,
      projectId: projectId,
      doer: const OneAgentDoer(AgentKind.claudeCode),
      runsOn: base.runsOn,
      agentPlace: base.agentPlace,
      skills: skills,
      usesAutomaticSkills: base.usesAutomaticSkills,
      approvalPolicy: base.approvalPolicy,
    ),
    schedule: null,
    status: TaskStatus.toDo,
    createdAt: randomUtcMoment(random),
  );
}

void _seedWork(
  Random random,
  SimulatedWorkNode work, {
  required List<Project> projects,
  required List<Skill> skills,
  required List<Task> tasks,
  required List<Run> runs,
}) {
  final int count = random.nextInt(_largestTaskCount + 1);
  for (int index = 0; index < count; index += 1) {
    final List<SkillId> taskSkills = <SkillId>[
      for (final Skill skill in skills)
        if (random.nextBool()) skill.id,
    ];
    final Task task = _buildTwinTask(
      random,
      index: index,
      projectId: pickOne(random, projects).id,
      skills: taskSkills,
    );
    tasks.add(task);
    work.tasks[task.id.value] = <String, Object?>{
      'id': task.id.value,
      'project_id': task.projectId.value,
      'skills': <Object?>[for (final SkillId id in taskSkills) id.value],
    };
    final int runCount = random.nextInt(_largestRunsPerTask + 1);
    for (int number = 1; number <= runCount; number += 1) {
      final String runId = 'twin-run-$index-$number';
      final String status = pickOne(random, nodeRunStatuses);
      runs.add(
        buildSeededRun(
          random,
          runId: runId,
          taskId: task.id,
          number: number,
          status: status,
        ),
      );
      work.runs[runId] = <String, Object?>{
        'id': runId,
        'task_id': task.id.value,
        'status': status,
      };
    }
  }
}

CatalogTwinSeeds seedCatalogTwins(
  Random random,
  SimulatedCatalogNode simulated,
  int workspaceCount,
) {
  final List<WorkspaceId> workspaceIds = <WorkspaceId>[
    for (int index = 0; index < workspaceCount; index += 1)
      WorkspaceId(simulated.addWorkspace('team-$index')['id']! as String),
  ];
  final List<Project> projects = _seedProjects(
    random,
    simulated,
    workspaceIds,
  );
  final List<Skill> skills = _seedSkills(
    random,
    simulated,
    workspaceIds,
    projects,
  );
  final List<Rule> rules = _seedRules(
    random,
    simulated,
    workspaceIds,
    projects,
  );
  final List<Task> tasks = <Task>[];
  final List<Run> runs = <Run>[];
  _seedWork(
    random,
    simulated.work,
    projects: projects,
    skills: skills,
    tasks: tasks,
    runs: runs,
  );
  return (
    workspaceIds: workspaceIds,
    projects: projects,
    skills: skills,
    rules: rules,
    tasks: tasks,
    runs: runs,
  );
}
