import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/agent_place_text.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/notice_banner.dart';

class RunnerProblemBanner extends StatelessWidget {
  const RunnerProblemBanner({
    required this.problem,
    required this.onRunLocally,
    super.key,
  });

  final String problem;
  final VoidCallback? onRunLocally;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? runLocally = onRunLocally;

    return NoticeBanner(
      tone: BannerTone.attention,
      icon: AppIconKind.alert,
      title: runnerProblemTitle,
      body: <Widget>[Text(problem)],
      actions: <Widget>[
        if (runLocally != null)
          AppButton.secondary(label: runLocallyLabel, onPressed: runLocally),
      ],
    );
  }
}
