import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/widgets/notice_banner.dart';

const String peerAddressProblemTitle =
    'Other devices cannot reach this one directly';
const String _peerAddressFallbackNote =
    'Live runs and chat go through the app server until this is fixed.';

class PeerAddressBanner extends StatelessWidget {
  const PeerAddressBanner({required this.problem, super.key});

  final String problem;

  @override
  Widget build(BuildContext context) {
    return NoticeBanner(
      tone: BannerTone.attention,
      icon: AppIconKind.alert,
      title: peerAddressProblemTitle,
      body: <Widget>[Text(problem), const Text(_peerAddressFallbackNote)],
    );
  }
}
