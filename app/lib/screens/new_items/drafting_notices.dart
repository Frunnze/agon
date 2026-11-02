import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/notice_banner.dart';

class NoRunnerNotice extends StatelessWidget {
  const NoRunnerNotice({required this.onFillForm, super.key});

  final VoidCallback onFillForm;

  @override
  Widget build(BuildContext context) {
    return NoticeBanner(
      tone: BannerTone.attention,
      icon: AppIconKind.offline,
      title: noRunnerTitle,
      body: const <Widget>[Text(noRunnerText)],
      actions: <Widget>[
        AppButton.secondary(label: fillInFormLabel, onPressed: onFillForm),
      ],
    );
  }
}
