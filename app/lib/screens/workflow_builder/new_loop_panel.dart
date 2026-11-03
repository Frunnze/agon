import 'package:flutter/material.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/connection_rules.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/gaps.dart';

const String newLoopTitle = 'New loop';
const String addLoopLabel = 'Add loop';
const String chooseRoundsProblem = 'Choose how many rounds it may go back';

class NewLoopPanel extends StatefulWidget {
  const NewLoopPanel({
    required this.workflow,
    required this.connection,
    required this.onLoopAdded,
    required this.onCancelled,
    super.key,
  });

  final Workflow workflow;
  final AgentConnection connection;
  final ValueChanged<AgentConnection> onLoopAdded;
  final VoidCallback onCancelled;

  @override
  State<NewLoopPanel> createState() => _NewLoopPanelState();
}

class _NewLoopPanelState extends State<NewLoopPanel> {
  final TextEditingController _outcomeController = TextEditingController();
  int? _roundLimit;
  String? _outcomeProblem;
  String? _roundsProblem;

  @override
  void dispose() {
    _outcomeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: spaceVertically(<Widget>[
        const PanelHeading(title: newLoopTitle, onDone: null),
        ConnectionHeading(
          workflow: widget.workflow,
          connection: widget.connection,
          note: goesBackText,
        ),
        OutcomeField(
          controller: _outcomeController,
          hint: loopOutcomeHint,
          problem: _outcomeProblem,
          onChanged: (String _) => setState(() => _outcomeProblem = null),
        ),
        RoundLimitField(
          roundLimit: _roundLimit,
          problem: _roundsProblem,
          onChanged: (int rounds) => setState(() {
            _roundLimit = rounds;
            _roundsProblem = null;
          }),
        ),
        Wrap(
          spacing: AppSpacing.space2,
          runSpacing: AppSpacing.space2,
          children: <Widget>[
            AppButton.secondary(
              label: 'Cancel',
              onPressed: widget.onCancelled,
            ),
            AppButton.primary(label: addLoopLabel, onPressed: _addLoop),
          ],
        ),
      ], AppSpacing.space4),
    );
  }

  String? _describeOutcomeProblem(String outcome) {
    if (outcome.isEmpty) {
      return loopNeedsOutcomeProblem;
    }
    return describeOutcomeProblem(
      workflow: widget.workflow,
      connection: widget.connection,
      outcome: outcome,
    );
  }

  void _addLoop() {
    final String outcome = _outcomeController.text.trim();
    final int? roundLimit = _roundLimit;
    final String? outcomeProblem = _describeOutcomeProblem(outcome);
    final String? roundsProblem = roundLimit == null
        ? chooseRoundsProblem
        : null;

    setState(() {
      _outcomeProblem = outcomeProblem;
      _roundsProblem = roundsProblem;
    });
    if (outcomeProblem != null || roundLimit == null) {
      return;
    }

    widget.onLoopAdded(
      widget.connection.withCondition(outcome).withRoundLimit(roundLimit),
    );
  }
}
