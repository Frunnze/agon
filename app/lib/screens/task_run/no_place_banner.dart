import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/agent_place_text.dart';
import 'package:agent_orchestration/widgets/notice_banner.dart';

class NoPlaceBanner extends StatelessWidget {
  const NoPlaceBanner({required this.place, super.key});

  final AgentPlace place;

  @override
  Widget build(BuildContext context) {
    return NoticeBanner(
      tone: BannerTone.attention,
      icon: AppIconKind.alert,
      title: describeMissingPlaceTitle(place),
      body: <Widget>[Text(describeMissingPlaceDetail(place))],
    );
  }
}
