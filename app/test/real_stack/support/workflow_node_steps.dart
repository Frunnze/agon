import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/drafting_task_views.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/workflow_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/workflow_views.dart' as node;
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart'
    as node;
import 'package:agent_orchestration/bridge/commands/drafting_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/commands/project_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/commands/workflow_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import 'real_stack.dart';
import 'runner_device.dart';
import 'stack_pairing.dart';
import 'stack_waiting.dart';

const String draftingProjectName = 'acme-app';
const String draftedAgentName = 'plan';
const String draftedAgentTask = 'Read the code and write a plan.';
const WorkflowAgentId draftedAgentId = WorkflowAgentId(
  '00000000-0000-0000-0000-000000000011',
);
const String _plainDraftDescription = 'Read the code and plan a feature.';
const String _defaultBranch = 'main';

final class DraftingStage {
  const DraftingStage({required this.runner, required this.project});

  final RunnerDevice runner;
  final node.Project project;
}

final class _DraftWatch {
  _DraftWatch({required this.channel, required this.statusCommand});

  final NodeCommandChannel channel;
  final node.WorkflowDraftStatusCommand statusCommand;
  node.WorkflowView? _draftedWorkflow;

  node.WorkflowView get draftedWorkflow {
    final node.WorkflowView? finishedWorkflow = _draftedWorkflow;
    if (finishedWorkflow == null) {
      throw StateError('The draft has not finished');
    }
    return finishedWorkflow;
  }

  Future<bool> isDone() async {
    final node.DraftStatus status = await channel.execute(statusCommand);
    if (status is node.DraftDone) {
      _draftedWorkflow = status.workflow;
    }
    return _draftedWorkflow != null;
  }
}

Future<DraftingStage> prepareDraftingStage(
  WidgetTester tester, {
  required RealStack stack,
}) async {
  final RunnerDevice runner = await startPairedRunner(tester, stack: stack);
  final node.CreateProjectCommand createProject = node.CreateProjectCommand(
    workspaceId: stack.homeWorkspaceId,
    projectName: draftingProjectName,
    repositories: const <node.Repository>[
      node.Repository(
        address: localRepositoryAddress,
        defaultBranch: _defaultBranch,
        agentAccess: node.AgentAccess.readOnly,
      ),
    ],
    approvalPolicy: null,
  );
  final node.Project project = await askNode(
    tester,
    () => stack.channel.execute(createProject),
  );
  return DraftingStage(runner: runner, project: project);
}

Future<node.WorkflowView> draftWorkflowOnNode(
  WidgetTester tester, {
  required RealStack stack,
  required DraftingStage stage,
  required String workflowName,
}) async {
  final node.DraftWorkflowCommand draftCommand = node.DraftWorkflowCommand(
    workspaceId: stack.homeWorkspaceId,
    description: describeNamedDraft(_plainDraftDescription, workflowName),
  );
  final node.WorkflowAgentTaskView started = await askNode(
    tester,
    () => stack.channel.execute(draftCommand),
  );

  final _DraftWatch watch = _DraftWatch(
    channel: stack.channel,
    statusCommand: node.WorkflowDraftStatusCommand(
      workspaceId: stack.homeWorkspaceId,
      taskId: started.taskId,
      workflowId: started.workflowId,
    ),
  );
  await waitUntilNodeAgrees(
    tester,
    description: 'the draft of $workflowName saved',
    check: watch.isDone,
  );
  return watch.draftedWorkflow;
}

String describeNamedDraft(String description, String chosenName) {
  return '$description Name it $chosenName.';
}

Future<List<node.WorkflowView>> fetchWorkflowViews(RealStack stack) {
  return stack.channel.execute(
    node.ListWorkflowsCommand(workspaceId: stack.homeWorkspaceId),
  );
}

node.WorkflowView? findWorkflowViewNamed(
  List<node.WorkflowView> views,
  String workflowName,
) {
  for (final node.WorkflowView view in views) {
    if (view.workflow.name == workflowName) {
      return view;
    }
  }
  return null;
}

node.WorkflowView requireWorkflowViewNamed(
  List<node.WorkflowView> views,
  String workflowName,
) {
  final node.WorkflowView? view = findWorkflowViewNamed(views, workflowName);
  if (view == null) {
    throw TestFailure('The node does not list workflow $workflowName');
  }
  return view;
}

Future<node.WorkflowView> fetchWorkflowView(
  RealStack stack,
  WorkflowId workflowId,
) async {
  final List<node.WorkflowView> views = await fetchWorkflowViews(stack);
  for (final node.WorkflowView view in views) {
    if (view.workflow.id == workflowId) {
      return view;
    }
  }
  throw TestFailure('The node does not list workflow $workflowId');
}

Future<bool> hasSignatureState(
  RealStack stack, {
  required WorkflowId workflowId,
  required node.SignatureState state,
}) async {
  final node.WorkflowView view = await fetchWorkflowView(stack, workflowId);
  return view.signatureState == state;
}

Future<node.WorkflowView> signWorkflowOnNode(
  WidgetTester tester, {
  required RealStack stack,
  required WorkflowId workflowId,
}) {
  return askNode(
    tester,
    () => stack.channel.execute(
      node.SignWorkflowCommand(workflowId: workflowId),
    ),
  );
}

node.WorkflowAgent findNodeAgentNamed(
  node.Workflow workflow,
  String agentName,
) {
  for (final node.WorkflowAgent agent in workflow.agents) {
    if (agent.name == agentName) {
      return agent;
    }
  }
  throw TestFailure('Workflow ${workflow.name} has no agent $agentName');
}

node.WorkflowAgent _rewriteTask(node.WorkflowAgent agent, String task) {
  return node.WorkflowAgent(
    stepKind: node.StepKind.agent,
    id: agent.id,
    name: agent.name,
    kind: agent.kind,
    task: task,
    runsOn: agent.runsOn,
    skills: agent.skills,
    usesAutomaticSkills: agent.usesAutomaticSkills,
    approvalPolicy: agent.approvalPolicy,
    position: agent.position,
  );
}

Future<node.WorkflowView> saveAgentTaskOnNode(
  WidgetTester tester, {
  required RealStack stack,
  required node.Workflow workflow,
  required String agentName,
  required String task,
}) {
  final List<node.WorkflowAgent> rewrittenAgents = <node.WorkflowAgent>[
    for (final node.WorkflowAgent agent in workflow.agents)
      if (agent.name == agentName) _rewriteTask(agent, task) else agent,
  ];
  final node.Workflow changedWorkflow = node.Workflow(
    id: workflow.id,
    name: workflow.name,
    availability: workflow.availability,
    agents: rewrittenAgents,
    connections: workflow.connections,
    signature: null,
  );
  return askNode(
    tester,
    () => stack.channel.execute(
      node.SaveWorkflowCommand(
        workspaceId: stack.homeWorkspaceId,
        workflow: changedWorkflow,
      ),
    ),
  );
}
