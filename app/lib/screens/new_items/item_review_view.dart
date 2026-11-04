import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/screens/new_items/change_request_composer.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';
import 'package:agent_orchestration/screens/shared/muted_note.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/app_page.dart';
import 'package:agent_orchestration/widgets/gaps.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/notice_banner.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

class ItemReviewView extends StatelessWidget {
  const ItemReviewView({
    required this.texts,
    required this.problems,
    required this.approvalProblem,
    required this.form,
    required this.onCancel,
    required this.onAskForChanges,
    super.key,
  });

  final NewItemTexts texts;
  final List<String> problems;
  final String? approvalProblem;
  final Widget form;
  final VoidCallback onCancel;
  final ValueChanged<String> onAskForChanges;

  @override
  Widget build(BuildContext context) {
    final String? approvalProblemText = approvalProblem;

    return AppPage(
      children: <Widget>[
        PageHeader(
          title: texts.pageTitle,
          summary: const <TextSegment>[TextSegment(reviewSummary)],
          backLink: BackLink(label: texts.sectionLabel, onPressed: onCancel),
        ),
        if (problems.isNotEmpty)
          NoticeBanner(
            tone: BannerTone.attention,
            icon: AppIconKind.alert,
            title: draftProblemsTitle,
            body: <Widget>[
              for (final String problem in problems) Text(problem),
              const MutedNote(draftProblemsNote),
            ],
          ),
        if (approvalProblemText != null)
          NoticeBanner(
            tone: BannerTone.danger,
            icon: AppIconKind.alert,
            title: approvalFailedTitle,
            body: <Widget>[Text(approvalProblemText)],
          ),
        form,
        Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSizes.measure),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: spaceVertically(<Widget>[
                ChangeRequestComposer(
                  example: texts.changeExample,
                  onSend: onAskForChanges,
                ),
                const Text(changeHint, style: AppTextStyles.smallMuted),
              ], AppSpacing.space2),
            ),
          ),
        ),
      ],
    );
  }
}
