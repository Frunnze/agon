import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/screens/files/file_frames.dart';
import 'package:agent_orchestration/screens/files/no_runner_text.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

const String tryAgainLabel = 'Try again';
const String seeRunnersLabel = 'See runners';

class NoRunnerView extends StatelessWidget {
  const NoRunnerView({
    required this.holders,
    required this.repositoryPath,
    required this.now,
    required this.onTryAgain,
    required this.onSeeRunners,
    super.key,
  });

  final List<RepositoryHolder> holders;
  final String repositoryPath;
  final DateTime now;
  final VoidCallback onTryAgain;
  final VoidCallback onSeeRunners;

  @override
  Widget build(BuildContext context) {
    return EmptySection(
      title: describeNoRunnerTitle(repositoryPath),
      children: <Widget>[
        MixedText(
          describeNoRunnerExplanation(
            holders: holders,
            repositoryPath: repositoryPath,
            now: now,
          ),
        ),
        Text(
          describeNoRunnerAdvice(
            holderCount: holders.length,
            repositoryPath: repositoryPath,
          ),
          style: AppTextStyles.body.copyWith(color: AppColors.inkMuted),
        ),
        Wrap(
          spacing: AppSpacing.space2,
          runSpacing: AppSpacing.space2,
          children: <Widget>[
            AppButton.secondary(
              label: tryAgainLabel,
              icon: AppIconKind.retry,
              onPressed: onTryAgain,
            ),
            AppButton.secondary(
              label: seeRunnersLabel,
              onPressed: onSeeRunners,
            ),
          ],
        ),
      ],
    );
  }
}
