import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';
import 'package:agent_orchestration/screens/shared/agent_login_pointer.dart';
import 'package:agent_orchestration/screens/workflows/workflow_drafting_screen.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/app_page.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/notice_banner.dart';
import 'package:agent_orchestration/widgets/page_header.dart';
import 'package:agent_orchestration/widgets/page_section.dart';
import 'package:agent_orchestration/widgets/status_label.dart';

String describeItemDrafter({
  required DraftRunning? running,
  required DeviceNames deviceNames,
}) {
  if (running == null) {
    return startingDraftText;
  }

  final String device = deviceNames.describeDevice(running.drafterDeviceId);
  return '${running.drafterKind.label} is drafting on $device';
}

final class DraftingState {
  const DraftingState({
    required this.drafterText,
    required this.draftProblem,
    required this.stopProblem,
    required this.returnLabel,
    required this.loginPointer,
  });

  final String drafterText;
  final String? draftProblem;
  final String? stopProblem;
  final String returnLabel;
  final AgentLoginPointer? loginPointer;
}

DraftingState describeDraftingState({
  required DraftRunning? running,
  required String? draftProblem,
  required String? stopProblem,
  required String returnLabel,
  required DeviceRepository deviceRepository,
  required AppNavigation navigation,
}) {
  final DeviceNames deviceNames = DeviceNames(deviceRepository.listDevices());
  return DraftingState(
    drafterText: describeItemDrafter(
      running: running,
      deviceNames: deviceNames,
    ),
    draftProblem: draftProblem,
    stopProblem: stopProblem,
    returnLabel: returnLabel,
    loginPointer: pointToAgentLogin(
      reason: draftProblem,
      runner: running?.drafterDeviceId,
      deviceRepository: deviceRepository,
      navigation: navigation,
    ),
  );
}

class ItemDraftingView extends StatelessWidget {
  const ItemDraftingView({
    required this.texts,
    required this.wish,
    required this.state,
    required this.onStop,
    required this.onReturn,
    required this.onLeave,
    required this.onFillForm,
    super.key,
  });

  final NewItemTexts texts;
  final String wish;
  final DraftingState state;
  final VoidCallback onStop;
  final VoidCallback onReturn;
  final VoidCallback onLeave;
  final VoidCallback onFillForm;

  @override
  Widget build(BuildContext context) {
    final String? draftProblem = state.draftProblem;
    final String? stopProblem = state.stopProblem;

    return AppPage(
      children: <Widget>[
        PageHeader(
          title: texts.pageTitle,
          summary: const <TextSegment>[TextSegment(draftingSummary)],
          backLink: BackLink(label: texts.sectionLabel, onPressed: onLeave),
          actions: <Widget>[
            if (draftProblem == null)
              AppButton.secondary(label: stopDraftingLabel, onPressed: onStop)
            else
              AppButton.primary(label: state.returnLabel, onPressed: onReturn),
          ],
        ),
        if (draftProblem == null)
          StatusLabel(
            text: state.drafterText,
            tone: StatusTone.normal,
            icon: AppIconKind.spinner,
          )
        else
          NoticeBanner(
            tone: BannerTone.danger,
            icon: AppIconKind.alert,
            title: draftFailedTitle,
            body: <Widget>[
              Text(draftProblem),
              ...describeAgentLoginPointer(state.loginPointer),
            ],
            actions: <Widget>[
              ...offerAgentLoginConnection(state.loginPointer),
              AppButton.secondary(
                label: fillInFormLabel,
                onPressed: onFillForm,
              ),
            ],
          ),
        if (draftProblem == null && stopProblem != null)
          NoticeBanner(
            tone: BannerTone.danger,
            icon: AppIconKind.alert,
            title: stopFailedTitle,
            body: <Widget>[Text(stopProblem)],
          ),
        PageSection(
          title: askedSectionTitle,
          children: <Widget>[Text(wish, style: AppTextStyles.body)],
        ),
      ],
    );
  }
}
