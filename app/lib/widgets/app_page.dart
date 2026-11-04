import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/theme/layout_size.dart';
import 'package:agent_orchestration/theme/page_metrics.dart';
import 'package:agent_orchestration/widgets/gaps.dart';

class AppPage extends StatelessWidget {
  const AppPage({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final LayoutSize layoutSize = LayoutSize.of(context);

    return SingleChildScrollView(
      padding: pagePaddingFor(layoutSize),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: spaceVertically(children, pageGap),
      ),
    );
  }
}
