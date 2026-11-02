import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflow_agents.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/workflow.dart';

const List<int> _sampleSignature = <int>[9, 8, 7, 6];

const String releaseDocument =
    'name: release\n'
    'steps:\n'
    '  - name: plan\n'
    '    runs_on: office-server\n'
    '  - name: build-ios\n'
    '    runs_on: mac-studio\n'
    '  - name: train\n'
    '    requires: [gpu]\n';

const String trainRankerSignedDocument =
    'name: train-ranker\n'
    'steps:\n'
    '  - name: prepare\n'
    '    runs_on: office-server\n'
    '  - name: train\n'
    '    requires: [gpu]\n'
    '    timeout: 2h\n';

const String trainRankerChangedDocument =
    'name: train-ranker\n'
    'steps:\n'
    '  - name: prepare\n'
    '    runs_on: office-server\n'
    '  - name: train\n'
    '    requires: [gpu]\n'
    '    timeout: 6h\n'
    '    egress: [huggingface.co]\n';

final OnlyWorkspaces _inAcme = OnlyWorkspaces(const <WorkspaceId>[
  GalleryWorkspaceIds.acme,
]);

WorkflowSignature _signedOnAirLaptop(String document, int daysAgo) {
  return WorkflowSignature(
    signedBy: GalleryDeviceIds.airLaptop,
    signature: _sampleSignature,
    signedDocument: document,
    signedAt: galleryDaysAgo(daysAgo),
  );
}

Workflow _buildStackedWorkflow({
  required WorkflowId id,
  required String name,
  required List<(String, AgentKind, RunnerTarget)> steps,
  required WorkflowSignature? signature,
}) {
  final List<WorkflowAgent> agents = <WorkflowAgent>[];

  for (int row = 0; row < steps.length; row += 1) {
    final (String stepName, AgentKind kind, RunnerTarget runsOn) = steps[row];
    agents.add(
      buildGalleryAgent(
        workflowName: name,
        name: stepName,
        kind: kind,
        runsOn: runsOn,
        position: stackedPosition(row),
      ),
    );
  }

  return Workflow(
    id: id,
    name: name,
    availability: _inAcme,
    agents: agents,
    connections: connectInOrder(agents),
    signature: signature,
  );
}

final List<WorkflowAgent> releaseAgents = List<WorkflowAgent>.unmodifiable(
  <WorkflowAgent>[
    buildGalleryAgent(
      workflowName: 'release',
      name: 'plan',
      kind: AgentKind.claudeCode,
      runsOn: onOfficeServer,
      position: stackedPosition(0),
    ),
    buildGalleryAgent(
      workflowName: 'release',
      name: 'build-ios',
      kind: AgentKind.claudeCode,
      runsOn: onMacStudio,
      position: stackedPosition(1),
      skills: const <SkillId>[GallerySkillIds.iosRelease],
    ),
    buildGalleryAgent(
      workflowName: 'release',
      name: 'train',
      kind: AgentKind.codex,
      runsOn: onGpuRunner,
      position: stackedPosition(2),
    ),
  ],
);

final List<Workflow> galleryWorkflows = List<Workflow>.unmodifiable(<Workflow>[
  Workflow(
    id: GalleryWorkflowIds.release,
    name: 'release',
    availability: _inAcme,
    agents: releaseAgents,
    connections: connectInOrder(releaseAgents),
    signature: _signedOnAirLaptop(releaseDocument, 3),
  ),
  _buildStackedWorkflow(
    id: GalleryWorkflowIds.nightlyTests,
    name: 'nightly-tests',
    steps: <(String, AgentKind, RunnerTarget)>[
      ('test', AgentKind.claudeCode, onOfficeServer),
      ('report', AgentKind.geminiCli, onOfficeServer),
    ],
    signature: _signedOnAirLaptop('name: nightly-tests\n', 10),
  ),
  Workflow(
    id: GalleryWorkflowIds.featurePipeline,
    name: 'feature-pipeline',
    availability: const AllWorkspaces(),
    agents: featurePipelineAgents,
    connections: connectFeaturePipeline(),
    signature: null,
  ),
  _buildStackedWorkflow(
    id: GalleryWorkflowIds.trainRanker,
    name: 'train-ranker',
    steps: <(String, AgentKind, RunnerTarget)>[
      ('prepare', AgentKind.codex, onOfficeServer),
      ('train', AgentKind.codex, onGpuRunner),
    ],
    signature: _signedOnAirLaptop(trainRankerSignedDocument, 2),
  ),
  _buildStackedWorkflow(
    id: GalleryWorkflowIds.docsSync,
    name: 'docs-sync',
    steps: <(String, AgentKind, RunnerTarget)>[
      ('publish', AgentKind.claudeCode, onOfficeServer),
    ],
    signature: _signedOnAirLaptop('name: docs-sync\n', 20),
  ),
]);

final List<WorkflowChange> galleryWorkflowChanges =
    List<WorkflowChange>.unmodifiable(<WorkflowChange>[
      WorkflowChange(
        workflowId: GalleryWorkflowIds.trainRanker,
        changedBy: GalleryDeviceIds.airLaptop,
        changedAt: galleryNow.subtract(const Duration(hours: 1)),
        summary: 'Adds huggingface.co to its network allowlist',
        differences: const <WorkflowDifference>[
          WorkflowDifference(
            subject: 'Time limit for train',
            change: '2 h, now 6 h',
          ),
          WorkflowDifference(
            subject: 'Network for train',
            change: 'Can now reach huggingface.co',
          ),
        ],
        signedDocument: trainRankerSignedDocument,
        changedDocument: trainRankerChangedDocument,
      ),
    ]);
