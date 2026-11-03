import 'package:flutter/material.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/connection_rules.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/forms/form_field_block.dart';
import 'package:agent_orchestration/widgets/forms/select_entry.dart';
import 'package:agent_orchestration/widgets/forms/select_field.dart';

const String outcomeLabel = 'Outcome';
const String roundsLabel = 'Rounds';
const String goesBackText = 'Goes back to an earlier step';
const String chooseRoundsLabel = 'Choose how many rounds';
const String loopOutcomeHint =
    'The outcome that sends the work back, like changes.';

final TextStyle _problemStyle = AppTextStyles.small.copyWith(
  color: AppColors.danger,
);

final class RoundLimitChoice {
  const RoundLimitChoice(this.rounds);

  final int? rounds;

  @override
  bool operator ==(Object other) {
    return other is RoundLimitChoice && other.rounds == rounds;
  }

  @override
  int get hashCode => rounds.hashCode;
}

String describeConnectionEnds(Workflow workflow, AgentConnection connection) {
  final String fromName = workflow.findAgent(connection.from).name;
  final String toName = workflow.findAgent(connection.to).name;
  return '$fromName → $toName';
}

String describeForwardOutcomeHint(String fromName) {
  return 'Follow this only when $fromName ends with this outcome, like '
      'approved. Leave it empty to always follow.';
}

String describeRoundLimitChoice(int rounds) {
  final String unit = rounds == 1 ? 'round' : 'rounds';
  return 'Go back at most $rounds $unit';
}

List<SelectOption<RoundLimitChoice>> buildRoundLimitEntries(int? roundLimit) {
  return <SelectOption<RoundLimitChoice>>[
    if (roundLimit == null)
      const SelectOption<RoundLimitChoice>.disabled(
        value: RoundLimitChoice(null),
        label: chooseRoundsLabel,
      ),
    for (int rounds = fewestLoopRounds; rounds <= mostLoopRounds; rounds += 1)
      SelectOption<RoundLimitChoice>(
        value: RoundLimitChoice(rounds),
        label: describeRoundLimitChoice(rounds),
      ),
  ];
}

class ConnectionHeading extends StatelessWidget {
  const ConnectionHeading({
    required this.workflow,
    required this.connection,
    required this.note,
    super.key,
  });

  final Workflow workflow;
  final AgentConnection connection;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final String? noteText = note;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          describeConnectionEnds(workflow, connection),
          style: AppTextStyles.body.merge(AppTextStyles.monospace),
        ),
        if (noteText != null) Text(noteText, style: AppTextStyles.smallMuted),
      ],
    );
  }
}

class OutcomeField extends StatelessWidget {
  const OutcomeField({
    required this.controller,
    required this.hint,
    required this.problem,
    required this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final String hint;
  final String? problem;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return FormFieldBlock(
      label: outcomeLabel,
      hint: hint,
      children: <Widget>[
        TextField(
          controller: controller,
          autocorrect: false,
          style: AppTextStyles.body.merge(AppTextStyles.monospace),
          decoration: InputDecoration(errorText: problem),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class RoundLimitField extends StatelessWidget {
  const RoundLimitField({
    required this.roundLimit,
    required this.problem,
    required this.onChanged,
    super.key,
  });

  final int? roundLimit;
  final String? problem;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final String? problemText = problem;

    return FormFieldBlock(
      label: roundsLabel,
      children: <Widget>[
        SelectField<RoundLimitChoice>(
          value: RoundLimitChoice(roundLimit),
          entries: buildRoundLimitEntries(roundLimit),
          onChanged: _chooseRounds,
        ),
        if (problemText != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.space1),
            child: Text(problemText, style: _problemStyle),
          ),
      ],
    );
  }

  void _chooseRounds(RoundLimitChoice choice) {
    final int? rounds = choice.rounds;
    if (rounds != null) {
      onChanged(rounds);
    }
  }
}
