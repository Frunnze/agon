import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/rules/kept_branches.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/kept_branch_text.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/notice_banner.dart';

class NotPushedBanner extends StatelessWidget {
  const NotPushedBanner({
    required this.keptBranches,
    required this.deviceNames,
    required this.onBrowse,
    super.key,
  });

  final List<KeptBranch> keptBranches;
  final DeviceNames deviceNames;
  final ValueChanged<KeptBranch>? onBrowse;

  @override
  Widget build(BuildContext context) {
    final ValueChanged<KeptBranch>? browse = onBrowse;

    return NoticeBanner(
      tone: BannerTone.neutral,
      icon: AppIconKind.offline,
      title: keptBranchesTitle,
      body: <Widget>[
        for (final KeptBranch kept in keptBranches)
          MixedText(describeKeptBranch(kept: kept, deviceNames: deviceNames)),
      ],
      actions: <Widget>[
        if (browse != null)
          for (final KeptBranch kept in keptBranches)
            AppButton.secondary(
              label: describeKeptBranchLink(kept),
              onPressed: () => browse(kept),
            ),
      ],
    );
  }
}
