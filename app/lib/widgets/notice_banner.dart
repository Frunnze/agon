import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/icons/app_icon.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/gaps.dart';

enum BannerTone {
  neutral(AppColors.inkMuted, AppColors.sunken),
  attention(AppColors.attention, AppColors.attentionTint),
  danger(AppColors.danger, AppColors.dangerTint);

  const BannerTone(this.accent, this.tint);

  final Color accent;
  final Color tint;
}

class NoticeBanner extends StatelessWidget {
  const NoticeBanner({
    required this.tone,
    required this.icon,
    required this.title,
    super.key,
    this.body = const <Widget>[],
    this.actions = const <Widget>[],
  });

  final BannerTone tone;
  final AppIconKind icon;
  final String title;
  final List<Widget> body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final List<Widget> content = <Widget>[
      Text(title, style: AppTextStyles.bodyBold),
      ...body,
    ];

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.space4),
        decoration: BoxDecoration(
          color: tone.tint,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(AppRadii.panel),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AppIcon(icon, color: tone.accent),
            const SizedBox(width: AppSpacing.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ...spaceVertically(content, AppSpacing.space1),
                  if (actions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.space3),
                      child: Wrap(
                        spacing: AppSpacing.space2,
                        runSpacing: AppSpacing.space2,
                        children: actions,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
