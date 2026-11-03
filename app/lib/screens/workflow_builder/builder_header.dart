import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/icons/app_icon.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/compact_page_header.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

const String draftedNoteTitle = 'Drafted from your description';
const String draftedNoteText =
    'Check each agent before you sign. Change anything by hand: drag '
    'between dots, add agents, or edit the settings.';
const double _noteIconWithGapWidth = AppSizes.iconSmall + AppSpacing.space1;
final TextStyle _noteTitleStyle = AppTextStyles.smallMuted.copyWith(
  fontWeight: FontWeight.w700,
);

class BuilderHeader extends StatelessWidget {
  const BuilderHeader({
    required this.title,
    required this.summary,
    required this.onBack,
    required this.onCancel,
    required this.onSigned,
    super.key,
  });

  final String title;
  final String summary;
  final VoidCallback onBack;
  final VoidCallback onCancel;
  final VoidCallback onSigned;

  @override
  Widget build(BuildContext context) {
    return CompactPageHeader(
      title: title,
      summary: summary,
      backLink: BackLink(label: 'Workflows', onPressed: onBack),
      actions: <Widget>[
        AppButton.secondary(label: 'Cancel', onPressed: onCancel),
        AppButton.primary(label: 'Sign and save', onPressed: onSigned),
      ],
    );
  }
}

class DraftedNote extends StatelessWidget {
  const DraftedNote({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: _buildLine);
  }

  Widget _buildLine(BuildContext context, BoxConstraints limits) {
    final double titleWidthLimit = limits.maxWidth - _noteIconWithGapWidth;

    return Row(
      children: <Widget>[
        const AppIcon(
          AppIconKind.draft,
          size: AppIconSize.small,
          color: AppColors.inkMuted,
        ),
        const SizedBox(width: AppSpacing.space1),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: titleWidthLimit),
          child: Text(
            draftedNoteTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _noteTitleStyle,
          ),
        ),
        const Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: AppSpacing.space2),
            child: Text(
              draftedNoteText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.smallMuted,
            ),
          ),
        ),
      ],
    );
  }
}
