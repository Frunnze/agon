import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/workflow.dart';

const double _columnStart = 8;
const double _columnMiddle = 92;
const double _columnEnd = 176;
const double _rowHeight = 136;
const double _firstRow = 16;

WorkflowAgent buildGalleryAgent({
  required String workflowName,
  required String name,
  required AgentKind kind,
  required RunnerTarget runsOn,
  required CanvasPosition position,
  List<SkillId> skills = const <SkillId>[],
}) {
  return WorkflowAgent(
    stepKind: StepKind.agent,
    id: WorkflowAgentId('agent-$workflowName-$name'),
    name: name,
    kind: kind,
    task: 'Do the $name step of $workflowName.',
    runsOn: runsOn,
    skills: skills,
    usesAutomaticSkills: true,
    approvalPolicy: ApprovalPolicy.askBeforeRiskyActions,
    position: position,
  );
}

CanvasPosition stackedPosition(int row) {
  return CanvasPosition(
    horizontal: _columnMiddle,
    vertical: _firstRow + row * _rowHeight,
  );
}

const SpecificRunner onOfficeServer = SpecificRunner(
  GalleryDeviceIds.officeServer,
);
const SpecificRunner onMacStudio = SpecificRunner(GalleryDeviceIds.macStudio);
final RunnerWithLabels onGpuRunner = RunnerWithLabels(const <String>['gpu']);

final List<WorkflowAgent> featurePipelineAgents =
    List<WorkflowAgent>.unmodifiable(<WorkflowAgent>[
      buildGalleryAgent(
        workflowName: 'feature-pipeline',
        name: 'plan',
        kind: AgentKind.claudeCode,
        runsOn: onOfficeServer,
        position: stackedPosition(0),
      ),
      buildGalleryAgent(
        workflowName: 'feature-pipeline',
        name: 'backend',
        kind: AgentKind.codex,
        runsOn: onOfficeServer,
        position: const CanvasPosition(
          horizontal: _columnStart,
          vertical: _firstRow + _rowHeight,
        ),
      ),
      buildGalleryAgent(
        workflowName: 'feature-pipeline',
        name: 'ios',
        kind: AgentKind.claudeCode,
        runsOn: onMacStudio,
        position: const CanvasPosition(
          horizontal: _columnEnd,
          vertical: _firstRow + _rowHeight,
        ),
        skills: const <SkillId>[GallerySkillIds.iosRelease],
      ),
      buildGalleryAgent(
        workflowName: 'feature-pipeline',
        name: 'review',
        kind: AgentKind.geminiCli,
        runsOn: RunnerWithLabels(const <String>['linux']),
        position: stackedPosition(2),
        skills: const <SkillId>[GallerySkillIds.codeReview],
      ),
      buildGalleryAgent(
        workflowName: 'feature-pipeline',
        name: 'ship',
        kind: AgentKind.claudeCode,
        runsOn: onOfficeServer,
        position: stackedPosition(3),
      ),
    ]);

List<AgentConnection> connectInOrder(List<WorkflowAgent> agents) {
  final List<AgentConnection> connections = <AgentConnection>[];

  for (int index = 1; index < agents.length; index += 1) {
    connections.add(
      AgentConnection(
        from: agents[index - 1].id,
        to: agents[index].id,
        condition: null,
        roundLimit: null,
      ),
    );
  }

  return connections;
}

List<AgentConnection> connectFeaturePipeline() {
  final List<WorkflowAgent> agents = featurePipelineAgents;

  return <AgentConnection>[
    AgentConnection(
      from: agents[0].id,
      to: agents[1].id,
      condition: null,
      roundLimit: null,
    ),
    AgentConnection(
      from: agents[0].id,
      to: agents[2].id,
      condition: null,
      roundLimit: null,
    ),
    AgentConnection(
      from: agents[1].id,
      to: agents[3].id,
      condition: null,
      roundLimit: null,
    ),
    AgentConnection(
      from: agents[2].id,
      to: agents[3].id,
      condition: null,
      roundLimit: null,
    ),
    AgentConnection(
      from: agents[3].id,
      to: agents[4].id,
      condition: null,
      roundLimit: null,
    ),
  ];
}
