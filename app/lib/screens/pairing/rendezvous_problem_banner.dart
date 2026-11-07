import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/widgets/notice_banner.dart';

const String rendezvousProblemTitle =
    "Devices on other networks can't use this code";
const String rendezvousSameNetworkNote =
    'Devices on this network can still join with it.';

class RendezvousProblemBanner extends StatelessWidget {
  const RendezvousProblemBanner({required this.problem, super.key});

  final String problem;

  @override
  Widget build(BuildContext context) {
    return NoticeBanner(
      tone: BannerTone.attention,
      icon: AppIconKind.alert,
      title: rendezvousProblemTitle,
      body: <Widget>[
        const Text(rendezvousSameNetworkNote),
        Text(problem, style: const TextStyle(color: AppColors.inkMuted)),
      ],
    );
  }
}
