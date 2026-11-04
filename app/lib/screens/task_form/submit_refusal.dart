import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/widgets/notice_banner.dart';

final class SubmitRefusal {
  const SubmitRefusal({required this.actionLabel, required this.explanation});

  final String actionLabel;
  final String explanation;
}

class SubmitRefusalBanner extends StatelessWidget {
  const SubmitRefusalBanner({required this.refusal, super.key});

  final SubmitRefusal refusal;

  @override
  Widget build(BuildContext context) {
    return NoticeBanner(
      tone: BannerTone.danger,
      icon: AppIconKind.alert,
      title: '${refusal.actionLabel} did not work',
      body: <Widget>[Text(refusal.explanation)],
    );
  }
}
