import 'dart:math';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';

import 'fake_task_work_links.dart';
import 'random_inputs.dart';

const int _largestWorkflowCount = 5;

final class WorkflowInSignatureState {
  const WorkflowInSignatureState({
    required this.workflow,
    required this.state,
  });

  final Workflow workflow;
  final SignatureState state;

  bool get isSigned => state == SignatureState.signed;
}

List<WorkflowInSignatureState> randomWorkflowsInSignatureStates(
  Random random,
) {
  final int count = 1 + random.nextInt(_largestWorkflowCount);

  return <WorkflowInSignatureState>[
    for (int index = 0; index < count; index += 1)
      _buildWorkflowInState(
        state: pickOne(random, SignatureState.values),
        index: index,
      ),
  ];
}

FakeWorkflowRepository buildSignatureStateRepository(
  List<WorkflowInSignatureState> choices,
) {
  return FakeWorkflowRepository(
    workflows: <Workflow>[
      for (final WorkflowInSignatureState choice in choices) choice.workflow,
    ],
    changes: _listPendingChanges(choices),
    clock: FixedClock(galleryNow),
    currentDeviceId: GalleryDeviceIds.airLaptop,
    draftTemplate: galleryWorkflows.first,
    drafterDeviceId: GalleryDeviceIds.officeServer,
    draftStepDelay: Duration.zero,
    workspaceRepository: buildAcmeWorkspaceRepository(),
  );
}

WorkflowInSignatureState _buildWorkflowInState({
  required SignatureState state,
  required int index,
}) {
  final Workflow signedTemplate = galleryWorkflows.first;
  final bool hasSignature = state != SignatureState.notSignedYet;
  final Workflow workflow = Workflow(
    id: WorkflowId('signature-workflow-$index'),
    name: 'flow-$index',
    availability: signedTemplate.availability,
    agents: signedTemplate.agents,
    connections: signedTemplate.connections,
    signature: hasSignature ? signedTemplate.signature : null,
  );

  return WorkflowInSignatureState(workflow: workflow, state: state);
}

List<WorkflowChange> _listPendingChanges(
  List<WorkflowInSignatureState> choices,
) {
  final WorkflowChange template = galleryWorkflowChanges.first;

  return <WorkflowChange>[
    for (final WorkflowInSignatureState choice in choices)
      if (choice.state == SignatureState.changedNotSigned)
        WorkflowChange(
          workflowId: choice.workflow.id,
          changedBy: template.changedBy,
          changedAt: template.changedAt,
          summary: template.summary,
          differences: template.differences,
          signedDocument: template.signedDocument,
          changedDocument: template.changedDocument,
        ),
  ];
}
