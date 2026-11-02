import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/icons/app_icon.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

class FileSourceStatus extends StatelessWidget {
  const FileSourceStatus({required this.runnerName, super.key});

  final String runnerName;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const AppIcon(
          AppIconKind.lock,
          size: AppIconSize.small,
          color: AppColors.inkMuted,
        ),
        const SizedBox(width: AppSpacing.space1),
        Flexible(
          child: MixedText(<TextSegment>[
            const TextSegment('From '),
            TextSegment.monospace(runnerName),
            const TextSegment(' · encrypted'),
          ], style: AppTextStyles.smallMuted),
        ),
      ],
    );
  }
}
