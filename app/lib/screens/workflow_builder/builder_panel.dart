import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/workflow_edits.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/task_form/task_form_options.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

final class BuilderPanelActions {
  const BuilderPanelActions({
    required this.onAgentChanged,
    required this.onFillInRequested,
    required this.onAgentRemoved,
    required this.onConnectionChanged,
    required this.onConnectionRemoved,
    required this.onLoopAdded,
    required this.onDone,
  });

  final ValueChanged<WorkflowAgent> onAgentChanged;
  final ValueChanged<WorkflowAgentId>? onFillInRequested;
  final ValueChanged<WorkflowAgentId> onAgentRemoved;
  final ValueChanged<AgentConnection> onConnectionChanged;
  final ValueChanged<AgentConnection> onConnectionRemoved;
  final ValueChanged<AgentConnection> onLoopAdded;
  final VoidCallback onDone;
}

final class BuilderPanelSources {
  const BuilderPanelSources({
    required this.runners,
    required this.skills,
    required this.deviceNames,
  });

  final List<Runner> runners;
  final List<Skill> skills;
  final DeviceNames deviceNames;
}

Key _keyConnection(AgentConnection connection) {
  return ValueKey<String>('${connection.from.value} ${connection.to.value}');
}

Widget? buildBuilderPanel({
  required Workflow workflow,
  required BuilderSelection? selection,
  required BuilderPanelSources sources,
  required BuilderPanelActions actions,
}) {
  switch (selection) {
    case SelectedStep(:final WorkflowAgentId agentId):
      final bool isPresent = workflow.agents.any(
        (WorkflowAgent agent) => agent.id == agentId,
      );
      if (!isPresent) {
        return null;
      }
      return _buildStepPanel(
        workflow: workflow,
        agent: workflow.findAgent(agentId),
        sources: sources,
        actions: actions,
      );
    case SelectedConnection(:final AgentConnection connection):
      final bool isPresent = workflow.connections.any(
        (AgentConnection existing) => existing.joinsSameSteps(connection),
      );
      if (!isPresent) {
        return null;
      }
      return ConnectionSettingsPanel(
        key: _keyConnection(connection),
        workflow: workflow,
        connection: findConnection(workflow, connection),
        onConnectionChanged: actions.onConnectionChanged,
        onRemoved: () => actions.onConnectionRemoved(connection),
        onDone: actions.onDone,
      );
    case DrawnLoop(:final AgentConnection connection):
      return NewLoopPanel(
        key: _keyConnection(connection),
        workflow: workflow,
        connection: connection,
        onLoopAdded: actions.onLoopAdded,
        onCancelled: actions.onDone,
      );
    case null:
      return null;
  }
}

Widget _buildStepPanel({
  required Workflow workflow,
  required WorkflowAgent agent,
  required BuilderPanelSources sources,
  required BuilderPanelActions actions,
}) {
  final Key key = ValueKey<WorkflowAgentId>(agent.id);
  switch (agent.stepKind) {
    case StepKind.person:
      return PersonStepPanel(
        key: key,
        workflow: workflow,
        agent: agent,
        onAgentChanged: actions.onAgentChanged,
        onRemoved: () => actions.onAgentRemoved(agent.id),
        onDone: actions.onDone,
      );
    case StepKind.agent:
      final ValueChanged<WorkflowAgentId>? fillIn = actions.onFillInRequested;
      return AgentSettingsPanel(
        key: key,
        workflow: workflow,
        agent: agent,
        runnerOptions: buildRunnerOptions(
          runners: sources.runners,
          deviceNames: sources.deviceNames,
          chosenTarget: agent.runsOn,
        ),
        skills: sources.skills,
        onAgentChanged: actions.onAgentChanged,
        onFillInRequested: fillIn == null ? null : () => fillIn(agent.id),
        onRemoved: () => actions.onAgentRemoved(agent.id),
        onDone: actions.onDone,
      );
  }
}
