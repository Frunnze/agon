import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/shared/agent_login_pointer.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/widgets/notice_banner.dart';

class RunFailureBanner extends StatelessWidget {
  const RunFailureBanner({
    required this.failure,
    required this.deviceNames,
    required this.loginPointer,
    super.key,
  });

  final RunFailure failure;
  final DeviceNames deviceNames;
  final AgentLoginPointer? loginPointer;

  @override
  Widget build(BuildContext context) {
    final DeviceId? runner = failure.runner;
    final String runnerName = runner == null ? '' : deviceNames.nameOf(runner);
    final String title = runner == null
        ? '${failure.stepName} failed'
        : '${failure.stepName} failed on $runnerName';
    final String retryNote = failure.retryRunsOnSameRunner
        ? 'This step is pinned to $runnerName, so a retry runs there too.'
        : 'A retry can run on any matching runner.';

    return NoticeBanner(
      tone: BannerTone.danger,
      icon: AppIconKind.alert,
      title: title,
      body: <Widget>[
        Text(failure.reason),
        Text(retryNote, style: const TextStyle(color: AppColors.inkMuted)),
        ...describeAgentLoginPointer(loginPointer),
      ],
      actions: offerAgentLoginConnection(loginPointer),
    );
  }
}
