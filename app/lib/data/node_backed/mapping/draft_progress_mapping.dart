import 'package:agent_orchestration/bridge/codecs/run_values.dart' as node;
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workflow_draft.dart';
import 'package:agent_orchestration/data/rules/workflow_edits.dart';

const String pendingDraftStepsName = 'steps';

const String _unnamedDraftName = '';

Workflow buildDraftShell({required WorkflowId workflowId}) {
  return Workflow(
    id: workflowId,
    name: _unnamedDraftName,
    availability: OnlyWorkspaces(const <WorkspaceId>[]),
    agents: const <WorkflowAgent>[],
    connections: const <AgentConnection>[],
    signature: null,
  );
}

node.Run? findLatestRun(List<node.Run> runs) {
  if (runs.isEmpty) {
    return null;
  }

  node.Run latestRun = runs.first;
  for (final node.Run run in runs) {
    if (run.number > latestRun.number) {
      latestRun = run;
    }
  }
  return latestRun;
}

DeviceId? findDrafterDeviceId(List<node.Run> runs) {
  final node.Run? latestRun = findLatestRun(runs);
  if (latestRun == null) {
    return null;
  }

  for (final node.RunStep step in latestRun.steps) {
    final DeviceId? runner = step.runner;
    if (runner != null) {
      return runner;
    }
  }
  return null;
}

WorkflowDraftProgress? buildWorkingDraftProgress({
  required List<node.Run> runs,
  required Workflow draftShell,
  required AgentKind drafterKind,
}) {
  final DeviceId? drafterDeviceId = findDrafterDeviceId(runs);
  if (drafterDeviceId == null) {
    return null;
  }

  final PendingAgent pendingSteps = PendingAgent(
    name: pendingDraftStepsName,
    position: placeBelowAgents(draftShell.agents),
  );
  return WorkflowDraftProgress(
    workflow: draftShell,
    pendingAgents: <PendingAgent>[pendingSteps],
    drafterKind: drafterKind,
    drafterDeviceId: drafterDeviceId,
  );
}

WorkflowDraftProgress buildFinishedDraftProgress({
  required Workflow drafted,
  required List<node.Run> runs,
  required AgentKind drafterKind,
}) {
  final DeviceId? drafterDeviceId = findDrafterDeviceId(runs);
  if (drafterDeviceId == null) {
    throw StateError('The draft of ${drafted.name} finished on no runner');
  }

  return WorkflowDraftProgress(
    workflow: drafted,
    pendingAgents: const <PendingAgent>[],
    drafterKind: drafterKind,
    drafterDeviceId: drafterDeviceId,
  );
}
