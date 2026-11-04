import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/presentation/step_round_text.dart';
import 'package:agent_orchestration/screens/shared/status_labels.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/clickable.dart';
import 'package:agent_orchestration/widgets/gaps.dart';

const int _resultMaximumLines = 6;

class EarlierRoundsBlock extends StatelessWidget {
  const EarlierRoundsBlock({
    required this.step,
    required this.isShown,
    required this.onToggled,
    super.key,
  });

  final RunStep step;
  final bool isShown;
  final VoidCallback onToggled;

  @override
  Widget build(BuildContext context) {
    final int count = step.earlierRounds.length;
    final String toggleLabel = isShown
        ? describeHideEarlierRounds(count)
        : describeShowEarlierRounds(count);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: spaceVertically(<Widget>[
        Semantics(
          button: true,
          child: Clickable(
            onTap: onToggled,
            child: Text(
              toggleLabel,
              style: AppTextStyles.small.copyWith(
                color: AppColors.action,
                fontWeight: AppTextStyles.bodyBold.fontWeight,
              ),
            ),
          ),
        ),
        if (isShown)
          for (int index = 0; index < count; index += 1)
            _buildRound(step.earlierRounds[index], index + 1),
      ], AppSpacing.space2),
    );
  }

  Widget _buildRound(EarlierRound round, int roundNumber) {
    final String? result = round.result;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          describeEarlierRound(
            round: round,
            roundNumber: roundNumber,
            statusText: buildStepStatusLabel(round.status).text,
          ),
          style: AppTextStyles.small,
        ),
        if (result != null)
          Text(
            result,
            style: AppTextStyles.smallMuted,
            maxLines: _resultMaximumLines,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}
