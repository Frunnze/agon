import 'package:flutter/material.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/connection_rules.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/gaps.dart';

const String connectionPanelTitle = 'Connection';
const String removeConnectionLabel = 'Remove connection';

class ConnectionSettingsPanel extends StatefulWidget {
  const ConnectionSettingsPanel({
    required this.workflow,
    required this.connection,
    required this.onConnectionChanged,
    required this.onRemoved,
    required this.onDone,
    super.key,
  });

  final Workflow workflow;
  final AgentConnection connection;
  final ValueChanged<AgentConnection> onConnectionChanged;
  final VoidCallback onRemoved;
  final VoidCallback onDone;

  @override
  State<ConnectionSettingsPanel> createState() =>
      _ConnectionSettingsPanelState();
}

class _ConnectionSettingsPanelState extends State<ConnectionSettingsPanel> {
  late final TextEditingController _outcomeController = TextEditingController(
    text: widget.connection.condition ?? '',
  );
  String? _outcomeProblem;

  @override
  void dispose() {
    _outcomeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AgentConnection connection = widget.connection;
    final String fromName = widget.workflow.findAgent(connection.from).name;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: spaceVertically(<Widget>[
        PanelHeading(title: connectionPanelTitle, onDone: widget.onDone),
        ConnectionHeading(
          workflow: widget.workflow,
          connection: connection,
          note: connection.isLoop ? goesBackText : null,
        ),
        OutcomeField(
          controller: _outcomeController,
          hint: connection.isLoop
              ? loopOutcomeHint
              : describeForwardOutcomeHint(fromName),
          problem: _outcomeProblem,
          onChanged: _changeOutcome,
        ),
        if (connection.isLoop)
          RoundLimitField(
            roundLimit: connection.roundLimit,
            problem: null,
            onChanged: (int rounds) =>
                widget.onConnectionChanged(connection.withRoundLimit(rounds)),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: AppButton.secondary(
            label: removeConnectionLabel,
            onPressed: widget.onRemoved,
          ),
        ),
      ], AppSpacing.space4),
    );
  }

  void _changeOutcome(String text) {
    final AgentConnection connection = widget.connection;
    final String outcome = text.trim();
    if (outcome.isEmpty && !connection.isLoop) {
      setState(() => _outcomeProblem = null);
      widget.onConnectionChanged(connection.withCondition(null));
      return;
    }

    final String? problem = outcome.isEmpty
        ? loopNeedsOutcomeProblem
        : describeOutcomeProblem(
            workflow: widget.workflow,
            connection: connection,
            outcome: outcome,
          );
    setState(() => _outcomeProblem = problem);
    if (problem == null) {
      widget.onConnectionChanged(connection.withCondition(outcome));
    }
  }
}
