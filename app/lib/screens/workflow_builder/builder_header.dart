import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/notice_banner.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

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
    return PageHeader(
      title: title,
      summary: <TextSegment>[TextSegment(summary)],
      backLink: BackLink(label: 'Workflows', onPressed: onBack),
      actions: <Widget>[
        AppButton.secondary(label: 'Cancel', onPressed: onCancel),
        AppButton.primary(label: 'Sign and save', onPressed: onSigned),
      ],
    );
  }
}

class DraftedBanner extends StatelessWidget {
  const DraftedBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return const NoticeBanner(
      tone: BannerTone.neutral,
      icon: AppIconKind.draft,
      title: 'Drafted from your description',
      body: <Widget>[
        Text(
          'Check each agent before you sign. Change anything by hand: drag '
          'between dots, add agents, or edit the settings.',
        ),
      ],
    );
  }
}
