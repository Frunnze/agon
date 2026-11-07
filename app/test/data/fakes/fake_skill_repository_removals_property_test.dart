import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/task.dart';

import '../../support/fake_task_work_links.dart';
import '../../support/random_inputs.dart';
import '../../support/sample_records.dart';
import '../../support/sample_scopes.dart';
import 'support/notification_counter.dart';
import 'support/skill_inputs.dart';
import 'support/task_inputs.dart';
import 'support/workspace_scope_inputs.dart';
import 'support/workspace_skill_inputs.dart';

const String _typePrefix = 'test_fake_skill_repository';
const int _largestSkillCount = 6;
const List<WorkspaceId> _workspaceIds = <WorkspaceId>[
  WorkspaceId('workspace-acme'),
  WorkspaceId('workspace-personal'),
];
const List<ProjectId> _projectPool = <ProjectId>[
  ProjectId('project-app'),
  ProjectId('project-docs'),
  ProjectId('project-ünï'),
];

typedef _LinkedSkills = ({
  List<Skill> seeded,
  TaskSeed tasks,
  FakeSkillRepository skills,
  FakeTaskRepository taskRepository,
});

Skill _skillWithId(Random random, SkillId skillId, int index) {
  final Skill seeded = randomSeededSkill(random, index);
  return Skill(
    id: skillId,
    name: seeded.name,
    summary: seeded.summary,
    instructions: seeded.instructions,
    scope: randomScopeOver(random, _workspaceIds),
    usage: seeded.usage,
    source: seeded.source,
    improvement: seeded.improvement,
    history: seeded.history,
  );
}

_LinkedSkills _buildLinkedSkills(Random random) {
  final List<Skill> seeded = <Skill>[
    for (int index = 0; index < sampleSkillIds.length; index += 1)
      _skillWithId(random, sampleSkillIds[index], index),
  ];
  final TaskSeed tasks = randomTaskSeed(random);
  final FakeTaskRepository taskRepository = buildSeededTaskRepository(tasks);
  final FakeSkillRepository skills = buildSkillRepositoryIn(
    seeded,
    buildAcmeWorkspaceRepository(),
  );
  skills.linkTasks(taskRepository);
  return (
    seeded: seeded,
    tasks: tasks,
    skills: skills,
    taskRepository: taskRepository,
  );
}

List<List<SkillId>> _taskSkills(FakeTaskRepository repository) {
  return <List<SkillId>>[
    for (final Task task in repository.listTasksAndJobs()) task.skills,
  ];
}

List<List<SkillId>> _predictTaskSkills(TaskSeed seed, Set<SkillId> removed) {
  return <List<SkillId>>[
    for (final Task task in seed.tasks)
      <SkillId>[
        for (final SkillId skillId in task.skills)
          if (!removed.contains(skillId)) skillId,
      ],
  ];
}

Set<SkillId> _idsOf(List<Skill> skills) {
  return <SkillId>{for (final Skill skill in skills) skill.id};
}

Skill _everywhereWithProjects(Random random, int index) {
  final Skill seeded = randomSeededSkill(random, index);
  final ProjectScope projects = random.nextInt(3) == 0
      ? const AllProjects()
      : OnlyProjects(pickSome(random, _projectPool));
  return withSkillScope(
    seeded,
    Scope(workspaces: const AllWorkspaces(), projects: projects),
  );
}

List<ProjectId>? _listedProjects(Skill skill) {
  final ProjectScope projects = skill.scope.projects;
  if (projects is OnlyProjects) {
    return projects.projects;
  }
  return null;
}

void main() {
  test('${_typePrefix}_delete_skill_property_drops_the_skill_from_every_'
      'linked_task_and_job', () async {
    final Random random = seededRandom(91701);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _LinkedSkills linked = _buildLinkedSkills(random);
      final List<Skill> listed = linked.skills.listSkills();
      if (listed.isEmpty) {
        continue;
      }
      final Skill doomed = pickOne(random, listed);

      await linked.skills.deleteSkill(doomed.id);

      expect(
        _taskSkills(linked.taskRepository),
        _predictTaskSkills(linked.tasks, <SkillId>{doomed.id}),
      );
    }
  });

  test('${_typePrefix}_forget_workspace_property_drops_the_removed_skills_'
      'from_linked_tasks', () {
    final Random random = seededRandom(91702);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _LinkedSkills linked = _buildLinkedSkills(random);
      final WorkspaceId deleted = pickOne(random, _workspaceIds);
      final Set<WorkspaceId> remaining = <WorkspaceId>{
        for (final WorkspaceId workspaceId in _workspaceIds)
          if (workspaceId != deleted) workspaceId,
      };
      final Set<SkillId> removed = <SkillId>{
        for (final Skill skill in linked.seeded)
          if (isModelSeenInNoWorkspace(
            predictScopeAfterForget(skill.scope, deleted).workspaces,
            remaining,
          ))
            skill.id,
      };

      linked.skills.forgetWorkspace(
        deletedWorkspaceId: deleted,
        remainingWorkspaceIds: remaining,
      );

      expect(
        _taskSkills(linked.taskRepository),
        _predictTaskSkills(linked.tasks, removed),
      );
      expect(_idsOf(linked.skills.listSkills()).any(removed.contains), false);
    }
  });

  test('${_typePrefix}_link_tasks_property_the_latest_link_receives_the_'
      'removals_and_unlinked_tasks_stay', () async {
    final Random random = seededRandom(91703);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _LinkedSkills linked = _buildLinkedSkills(random);
      final FakeTaskRepository latest = buildSeededTaskRepository(
        linked.tasks,
      );
      linked.skills.linkTasks(latest);
      final Set<SkillId> deleted = _idsOf(linked.skills.listSkills());

      for (final SkillId skillId in deleted) {
        await linked.skills.deleteSkill(skillId);
      }

      expect(
        _taskSkills(linked.taskRepository),
        _predictTaskSkills(linked.tasks, <SkillId>{}),
      );
      expect(_taskSkills(latest), _predictTaskSkills(linked.tasks, deleted));
    }
  });

  test('${_typePrefix}_forget_projects_property_drops_the_projects_from_'
      'every_skill_scope', () {
    final Random random = seededRandom(91704);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int skillCount = 1 + random.nextInt(_largestSkillCount);
      final List<Skill> seeded = <Skill>[
        for (int index = 0; index < skillCount; index += 1)
          _everywhereWithProjects(random, index),
      ];
      final FakeSkillRepository repository = buildSkillRepositoryIn(
        seeded,
        buildAcmeWorkspaceRepository(),
      );
      final Set<ProjectId> forgotten = pickSome(random, _projectPool).toSet();

      repository.forgetProjects(forgotten);

      final List<Skill> listed = repository.listSkills();
      expect(listed, hasLength(seeded.length));
      for (int index = 0; index < seeded.length; index += 1) {
        final List<ProjectId>? before = _listedProjects(seeded[index]);
        final List<ProjectId>? after = _listedProjects(listed[index]);
        expect(listed[index].id, seeded[index].id);
        if (before == null) {
          expect(after, isNull);
          continue;
        }
        expect(after, <ProjectId>[
          for (final ProjectId projectId in before)
            if (!forgotten.contains(projectId)) projectId,
        ]);
      }
    }
  });

  test('${_typePrefix}_forget_projects_property_keeps_workspace_scopes_and_'
      'every_other_field', () {
    final Random random = seededRandom(91705);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _LinkedSkills linked = _buildLinkedSkills(random);
      final List<String> before = describeSkills(linked.skills.listSkills());
      final List<WorkspaceScope> workspacesBefore = <WorkspaceScope>[
        for (final Skill skill in linked.skills.listSkills())
          skill.scope.workspaces,
      ];

      linked.skills.forgetProjects(pickSome(random, _projectPool).toSet());

      expect(describeSkills(linked.skills.listSkills()), before);
      expect(<WorkspaceScope>[
        for (final Skill skill in linked.skills.listSkills())
          skill.scope.workspaces,
      ], workspacesBefore);
    }
  });

  test('${_typePrefix}_forget_projects_property_notifies_once_and_is_'
      'idempotent', () {
    final Random random = seededRandom(91706);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _LinkedSkills linked = _buildLinkedSkills(random);
      final NotificationCounter notifications = NotificationCounter();
      linked.skills.addListener(notifications.record);
      final Set<ProjectId> forgotten = pickSome(random, _projectPool).toSet();

      linked.skills.forgetProjects(forgotten);
      final List<List<ProjectId>?> once = <List<ProjectId>?>[
        for (final Skill skill in linked.skills.listSkills())
          _listedProjects(skill),
      ];
      linked.skills.forgetProjects(forgotten);

      expect(notifications.count, 2);
      expect(<List<ProjectId>?>[
        for (final Skill skill in linked.skills.listSkills())
          _listedProjects(skill),
      ], once);
    }
  });
}
