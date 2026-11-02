import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/screens/new_items/change_request_composer.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';
import 'package:agent_orchestration/screens/shared/muted_note.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/app_page.dart';
import 'package:agent_orchestration/widgets/fact_list.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/notice_banner.dart';
import 'package:agent_orchestration/widgets/page_header.dart';
import 'package:agent_orchestration/widgets/page_section.dart';
import 'package:agent_orchestration/widgets/split_layout.dart';

final class ReviewState {
  ReviewState({
    required this.facts,
    required List<String> problems,
    required this.approvalProblem,
  }) : problems = List<String>.unmodifiable(problems);

  final List<Fact> facts;
  final List<String> problems;
  final String? approvalProblem;
}

class ItemReviewView extends StatelessWidget {
  const ItemReviewView({
    required this.texts,
    required this.state,
    required this.onApprove,
    required this.onCancel,
    required this.onAskForChanges,
    super.key,
  });

  final NewItemTexts texts;
  final ReviewState state;
  final VoidCallback? onApprove;
  final VoidCallback onCancel;
  final ValueChanged<String> onAskForChanges;

  @override
  Widget build(BuildContext context) {
    final String? approvalProblem = state.approvalProblem;

    return AppPage(
      children: <Widget>[
        PageHeader(
          title: texts.pageTitle,
          summary: const <TextSegment>[TextSegment(reviewSummary)],
          backLink: BackLink(label: texts.sectionLabel, onPressed: onCancel),
          actions: <Widget>[
            AppButton.secondary(label: 'Cancel', onPressed: onCancel),
            AppButton.primary(
              label: approveLabel,
              icon: AppIconKind.check,
              onPressed: onApprove,
            ),
          ],
        ),
        if (state.problems.isNotEmpty)
          NoticeBanner(
            tone: BannerTone.attention,
            icon: AppIconKind.alert,
            title: draftProblemsTitle,
            body: <Widget>[
              for (final String problem in state.problems) Text(problem),
              const MutedNote(draftProblemsNote),
            ],
          ),
        if (approvalProblem != null)
          NoticeBanner(
            tone: BannerTone.danger,
            icon: AppIconKind.alert,
            title: approvalFailedTitle,
            body: <Widget>[Text(approvalProblem)],
          ),
        SplitLayout(
          start: PageSection(
            title: filledSectionTitle,
            children: <Widget>[FactList(facts: state.facts)],
          ),
          end: PageSection(
            title: changeSectionTitle,
            children: <Widget>[
              ChangeRequestComposer(
                example: texts.changeExample,
                onSend: onAskForChanges,
              ),
              const Text(changeHint, style: AppTextStyles.smallMuted),
            ],
          ),
        ),
      ],
    );
  }
}
