import 'dart:math';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/data/rules/naming.dart';
import 'package:agent_orchestration/data/rules/workflow_edits.dart';
import 'package:agent_orchestration/data/rules/workflow_problems.dart';
import 'package:agent_orchestration/screens/workflows/workflow_text.dart';

import '../../../support/fake_task_work_links.dart';
import '../../../support/random_branching_workflows.dart';
import '../../../support/random_inputs.dart';

const int featurePipelineIndex = 2;
const String sampleSignedDocument = 'name: sample\nsteps: signed\n';
const String sampleChangedDocument = 'name: sample\nsteps: changed\n';
const List<int> _sampleSignatureBytes = <int>[4, 2];
const int _largestSeededCount = 4;
const List<String> brokenWorkflowNames = <String>[
  '',
  'Has Space',
  'UPPER',
  'café',
  'under_score',
  'a-very-long-workflow-name-that-breaks-the-rule',
];
const List<String> brokenStepNames = <String>['Step One', 'build ios', 'É'];

typedef WorkflowBreaker = Workflow Function(Workflow workflow);

FakeWorkflowRepository buildWorkflowRepositoryIn({
  required List<Workflow> workflows,
  required List<WorkflowChange> changes,
  required WorkspaceRepository workspaceRepository,
}) {
  return FakeWorkflowRepository(
    workflows: workflows,
    changes: changes,
    clock: FixedClock(galleryNow),
    currentDeviceId: GalleryDeviceIds.airLaptop,
    draftTemplate: galleryWorkflows[featurePipelineIndex],
    drafterDeviceId: GalleryDeviceIds.officeServer,
    draftStepDelay: Duration.zero,
    workspaceRepository: workspaceRepository,
  );
}

FakeWorkflowRepository buildWorkflowRepository({
  required List<Workflow> workflows,
  required List<WorkflowChange> changes,
}) {
  return buildWorkflowRepositoryIn(
    workflows: workflows,
    changes: changes,
    workspaceRepository: buildAcmeWorkspaceRepository(),
  );
}

String? describeUploadProblem(Workflow workflow) {
  return describeNameProblem(workflow.name) ??
      describeWorkflowProblem(workflow);
}

WorkflowSignature buildSampleSignature() {
  return WorkflowSignature(
    signedBy: GalleryDeviceIds.macStudio,
    signature: _sampleSignatureBytes,
    signedDocument: sampleSignedDocument,
    signedAt: galleryDaysAgo(1),
  );
}

WorkflowChange buildSampleChange(WorkflowId workflowId) {
  return WorkflowChange(
    workflowId: workflowId,
    changedBy: GalleryDeviceIds.macStudio,
    changedAt: galleryDaysAgo(1),
    summary: 'Sample change',
    differences: const <WorkflowDifference>[],
    signedDocument: sampleSignedDocument,
    changedDocument: sampleChangedDocument,
  );
}

Workflow randomValidWorkflow(
  Random random, {
  required int index,
  required WorkflowSignature? signature,
}) {
  Workflow graph = randomBranchingWorkflow(random);
  while (graph.agents.isEmpty) {
    graph = randomBranchingWorkflow(random);
  }

  return Workflow(
    id: WorkflowId('seeded-workflow-$index'),
    name: 'seeded-$index',
    availability: graph.availability,
    agents: graph.agents,
    connections: graph.connections,
    signature: signature,
  );
}

List<Workflow> randomSeededWorkflows(Random random) {
  final int count = random.nextInt(_largestSeededCount + 1);
  final List<Workflow> workflows = <Workflow>[];

  for (int index = 0; index < count; index += 1) {
    final WorkflowSignature? signature = random.nextBool()
        ? buildSampleSignature()
        : null;
    workflows.add(
      randomValidWorkflow(random, index: index, signature: signature),
    );
  }
  return workflows;
}

List<WorkflowChange> randomChangesFor(Random random, List<Workflow> seeded) {
  return <WorkflowChange>[
    for (final Workflow workflow in seeded)
      if (workflow.signature != null && random.nextBool())
        buildSampleChange(workflow.id),
  ];
}

Workflow addBlankStep(Workflow workflow) {
  return addAgent(workflow, buildBlankAgent(workflow));
}

SignatureState readSignatureState(
  FakeWorkflowRepository repository,
  WorkflowId workflowId,
) {
  return findSignatureState(
    repository.findWorkflow(workflowId),
    repository.findPendingChange(workflowId),
  );
}

Workflow _renameWorkflowBadly(Random random, Workflow workflow) {
  return workflow.withName(pickOne(random, brokenWorkflowNames));
}

Workflow _renameStepBadly(Random random, Workflow workflow) {
  final WorkflowAgent renamed = workflow.agents.first.copyWith(
    name: pickOne(random, brokenStepNames),
  );
  return replaceAgent(workflow, renamed);
}

Workflow _repeatConnection(Workflow workflow) {
  return workflow.withGraph(
    agents: workflow.agents,
    connections: <AgentConnection>[
      ...workflow.connections,
      workflow.connections.first,
    ],
  );
}

Workflow _connectStepToItself(Workflow workflow) {
  final WorkflowAgentId agentId = workflow.agents.first.id;
  return workflow.withGraph(
    agents: workflow.agents,
    connections: <AgentConnection>[
      ...workflow.connections,
      AgentConnection(
        from: agentId,
        to: agentId,
        condition: null,
        roundLimit: null,
      ),
    ],
  );
}

Workflow breakWorkflow(Random random, Workflow workflow) {
  final int choice = random.nextInt(4);

  if (choice == 1 && workflow.agents.isNotEmpty) {
    return _renameStepBadly(random, workflow);
  }
  if (choice == 2 && workflow.connections.isNotEmpty) {
    return _repeatConnection(workflow);
  }
  if (choice == 3 && workflow.agents.isNotEmpty) {
    return _connectStepToItself(workflow);
  }
  return _renameWorkflowBadly(random, workflow);
}

FakeWorkflowRepository buildSeededWorkflowRepository(
  Random random,
  List<Workflow> seeded,
) {
  return buildWorkflowRepository(
    workflows: seeded,
    changes: randomChangesFor(random, seeded),
  );
}

typedef SeededWorkflows = ({
  FakeWorkflowRepository repository,
  List<Workflow> workflows,
  List<WorkflowChange> changes,
});

SeededWorkflows? seedRandomWorkflows(Random random) {
  final List<Workflow> workflows = randomSeededWorkflows(random);
  if (workflows.isEmpty) {
    return null;
  }
  final List<WorkflowChange> changes = randomChangesFor(random, workflows);
  return (
    repository: buildWorkflowRepository(
      workflows: workflows,
      changes: changes,
    ),
    workflows: workflows,
    changes: changes,
  );
}
