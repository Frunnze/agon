import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/agent_place_text.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/notice_banner.dart';

class RunnerProblemBanner extends StatelessWidget {
  const RunnerProblemBanner({
    required this.problem,
    required this.place,
    required this.onRunLocally,
    super.key,
  });

  final String problem;
  final AgentPlace? place;
  final VoidCallback onRunLocally;

  @override
  Widget build(BuildContext context) {
    final bool canRunLocally = place == AgentPlace.container;

    return NoticeBanner(
      tone: BannerTone.attention,
      icon: AppIconKind.alert,
      title: runnerProblemTitle,
      body: <Widget>[Text(problem)],
      actions: <Widget>[
        if (canRunLocally)
          AppButton.secondary(label: runLocallyLabel, onPressed: onRunLocally),
      ],
    );
  }
}
