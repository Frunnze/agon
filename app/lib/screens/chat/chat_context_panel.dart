import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/presentation/host_text.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/fact_list.dart';
import 'package:agent_orchestration/widgets/gaps.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

String describeRunSandbox(AgentPlace place) {
  switch (place) {
    case AgentPlace.container:
      return 'New container for this run. Sees only its workspace.';
    case AgentPlace.localProcess:
      return 'Runs on the runner itself, inside its workspace folder.';
  }
}

List<Fact> buildRunnerFacts({
  required Runner runner,
  required AgentPlace place,
}) {
  final Fact sandboxFact = Fact(
    term: 'Sandbox',
    description: <TextSegment>[TextSegment(describeRunSandbox(place))],
  );

  final bool isLimitedToHosts =
      place == AgentPlace.container && runner.allowedHosts.isNotEmpty;
  if (!isLimitedToHosts) {
    return <Fact>[sandboxFact];
  }

  return <Fact>[
    sandboxFact,
    Fact(
      term: 'Can reach',
      description: describeReachableHosts(runner.allowedHosts),
    ),
  ];
}

class ChatContextPanel extends StatelessWidget {
  const ChatContextPanel({
    required this.facts,
    required this.onOpenRun,
    super.key,
  });

  final List<Fact> facts;
  final VoidCallback onOpenRun;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSizes.chatContextWidth,
      padding: const EdgeInsets.only(left: AppSpacing.space6),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.line)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: spaceVertically(<Widget>[
            Semantics(
              header: true,
              child: const Text('This run', style: AppTextStyles.bodyBold),
            ),
            FactList(facts: facts),
            AppButton.secondary(label: 'Open run', onPressed: onOpenRun),
          ], AppSpacing.space5),
        ),
      ),
    );
  }
}
