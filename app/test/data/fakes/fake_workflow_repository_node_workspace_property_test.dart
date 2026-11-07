import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/workflow_views.dart' as node;
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/repository/workflow_repository.dart';

import '../../support/fake_task_work_links.dart';
import '../../support/random_inputs.dart';
import '../../support/workflow_repositories.dart';
import '../node_backed/support/simulated_workflow_node.dart';
import 'support/refusals.dart';
import 'support/task_inputs.dart';
import 'support/workflow_inputs.dart';
import 'support/workspace_inputs.dart';
import 'support/workspace_scope_inputs.dart';
import 'support/workspace_workflow_inputs.dart';

const String _typePrefix = 'test_fake_workflow_repository';
const int _sequenceIterations = 30;
const int _longestSequence = 10;
const int _largestSeededCount = 4;
const WorkflowId _missingWorkflowId = WorkflowId('workflow-missing');

enum _Operation { switchWorkspace, save, delete }

typedef _Pair = ({
  FakeWorkflowRepository fake,
  NodeBackedWorkflowRepository nodeBacked,
  FakeWorkspaceRepository workspaces,
  List<WorkspaceId> workspaceIds,
});

bool _isWorkflowRefusal(Object error) {
  return error is StateError ||
      error is ArgumentError ||
      error is RecordNotFound;
}

Object? _encodeWire(Object? json) => jsonDecode(jsonEncode(json));

Workflow _seedWorkflow(
  Random random,
  SimulatedWorkflowNode simulated,
  List<WorkspaceId> workspaceIds,
  int index,
) {
  final Map<String, Object?> view = simulated.addWorkflow(
    name: 'seeded-$index',
    state: pickOne(random, <String>[signedState, unsignedState]),
  );
  final Map<String, Object?> workflow =
      view['workflow']! as Map<String, Object?>;
  workflow['availability'] = _encodeWire(
    mapWorkspaceScopeToNode(randomWorkspaceScopeOver(random, workspaceIds))
        .toJson(),
  );
  return mapWorkflowFromNode(node.WorkflowView.fromJson(_encodeWire(view)));
}

List<Task> _seedUsingTasks(
  Random random,
  SimulatedWorkflowNode simulated,
  List<Workflow> workflows,
) {
  final List<Task> tasks = <Task>[];
  for (final Workflow workflow in workflows) {
    if (random.nextBool()) {
      continue;
    }
    final Task seeded = randomSeededTask(random, tasks.length);
    final Task task = Task(
      id: seeded.id,
      title: seeded.title,
      details: seeded.details,
      projectId: seeded.projectId,
      doer: WorkflowDoer(workflow.id),
      runsOn: seeded.runsOn,
      agentPlace: seeded.agentPlace,
      skills: seeded.skills,
      usesAutomaticSkills: seeded.usesAutomaticSkills,
      approvalPolicy: seeded.approvalPolicy,
      schedule: seeded.schedule,
      status: seeded.status,
      createdAt: seeded.createdAt,
    );
    tasks.add(task);
    simulated.tasks[task.id.value] = <String, Object?>{
      'id': task.id.value,
      'doer': <String, Object?>{
        'kind': 'workflow',
        'workflow_id': workflow.id.value,
      },
    };
  }
  return tasks;
}

FakeWorkflowRepository _buildFake(
  List<Workflow> workflows,
  List<Task> tasks,
  FakeWorkspaceRepository workspaces,
) {
  final FakeWorkflowRepository fake = buildWorkflowRepositoryIn(
    workflows: workflows,
    changes: const <WorkflowChange>[],
    workspaceRepository: workspaces,
  );
  final FakeTaskRepository taskRepository = buildTaskRepository(
    tasks: tasks,
    runs: const <Run>[],
    workflows: buildGalleryWorkflowRepository(),
  );
  fake.linkWork(
    taskWork: buildTaskWorkOver(taskRepository),
    approvalRepository: FakeApprovalRepository(
      approvals: const <ApprovalRequest>[],
      clock: FixedClock(galleryNow),
      currentDeviceId: GalleryDeviceIds.airLaptop,
    ),
  );
  return fake;
}

Future<_Pair> _buildPair(Random random) async {
  final SeededWorkspaces seeded = seedRandomWorkspaces(random);
  final List<WorkspaceId> workspaceIds = listWorkspaceIds(seeded.workspaces);
  final SimulatedWorkflowNode simulated = SimulatedWorkflowNode(
    pollsBeforeDraftIsDone: 1,
  );
  final int count = random.nextInt(_largestSeededCount + 1);
  final List<Workflow> workflows = <Workflow>[
    for (int index = 0; index < count; index += 1)
      _seedWorkflow(random, simulated, workspaceIds, index),
  ];
  final List<Task> tasks = _seedUsingTasks(random, simulated, workflows);
  final NodeBackedWorkflowRepository nodeBacked = NodeBackedWorkflowRepository(
    channel: simulated.channel,
    workspaceRepository: seeded.repository,
    draftPollInterval: Duration.zero,
  );
  await nodeBacked.load();
  return (
    fake: _buildFake(workflows, tasks, seeded.repository),
    nodeBacked: nodeBacked,
    workspaces: seeded.repository,
    workspaceIds: workspaceIds,
  );
}

String _describeWorkflow(Workflow workflow) {
  final Object? availability = mapWorkspaceScopeToNode(workflow.availability)
      .toJson();
  return '${workflow.id.value} ${workflow.name} $availability';
}

List<String> _describeListing(WorkflowRepository repository) {
  return <String>[
    for (final Workflow workflow in repository.listWorkflows())
      _describeWorkflow(workflow),
  ];
}

WorkflowId _pickWorkflowId(WorkflowRepository repository, int at) {
  final List<Workflow> listed = repository.listWorkflows();
  if (at >= listed.length) {
    return _missingWorkflowId;
  }
  return listed[at].id;
}

Future<Object?> _apply(
  WorkflowRepository repository,
  _Operation operation,
  int at,
  Workflow? moved,
) {
  final WorkflowId workflowId = _pickWorkflowId(repository, at);
  if (operation == _Operation.save && moved != null) {
    return repository.saveWorkflow(moved);
  }
  return repository.deleteWorkflow(workflowId);
}

Future<void> _runStep(Random random, _Pair pair, _Operation focus) async {
  final _Operation operation = random.nextInt(3) == 0
      ? pickOne(random, _Operation.values)
      : focus;
  if (operation == _Operation.switchWorkspace) {
    await pair.workspaces.switchWorkspace(pickOne(random, pair.workspaceIds));
    return;
  }
  final List<Workflow> listed = pair.nodeBacked.listWorkflows();
  final int at = random.nextInt(listed.length + 1);
  final Workflow? moved = at < listed.length
      ? withAvailability(
          listed[at],
          randomWorkspaceScopeOver(random, pair.workspaceIds),
        )
      : null;

  final bool isFakeRefused = await isRefused(
    () => _apply(pair.fake, operation, at, moved),
    isRefusal: _isWorkflowRefusal,
  );
  final bool isNodeRefused = await isRefused(
    () => _apply(pair.nodeBacked, operation, at, moved),
    isRefusal: _isWorkflowRefusal,
  );
  expect(isFakeRefused, isNodeRefused, reason: '$operation $at');
}

Future<void> _checkAgreement(_Operation focus, int seed) async {
  final Random random = seededRandom(seed);

  for (int i = 0; i < _sequenceIterations; i += 1) {
    final _Pair pair = await _buildPair(random);
    final int stepCount = 1 + random.nextInt(_longestSequence);

    for (int step = 0; step < stepCount; step += 1) {
      await _runStep(random, pair, focus);

      await pair.nodeBacked.load();
      expect(
        _describeListing(pair.fake),
        orderedEquals(_describeListing(pair.nodeBacked)),
      );
    }
    pair.nodeBacked.dispose();
    pair.fake.dispose();
  }
}

void main() {
  test('${_typePrefix}_list_workflows_property_agrees_with_the_node_'
      'across_workspaces', () async {
    await _checkAgreement(_Operation.switchWorkspace, 92401);
  });

  test('${_typePrefix}_save_workflow_property_moving_a_workflow_agrees_'
      'with_the_node', () async {
    await _checkAgreement(_Operation.save, 92402);
  });

  test('${_typePrefix}_delete_workflow_property_refuses_workflows_in_use_'
      'like_the_node', () async {
    await _checkAgreement(_Operation.delete, 92403);
  });
}
