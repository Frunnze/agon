import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/task_route_screens.dart';
import 'package:agent_orchestration/theme/layout_size.dart';
import 'package:agent_orchestration/theme/page_metrics.dart';
import 'package:agent_orchestration/widgets/app_page.dart';
import 'package:agent_orchestration/widgets/empty_state.dart';
import 'package:agent_orchestration/windows/keep_on_top_button.dart';
import 'package:agent_orchestration/windows/native_windows.dart';

const String _deletedRunTitle = 'This run was deleted';
const String _deletedRunMessage = 'Close this window to go on.';

class RunWindowScreen extends StatelessWidget {
  const RunWindowScreen({
    required this.navigation,
    required this.dependencies,
    required this.onTopSwitch,
    super.key,
  });

  final AppNavigation navigation;
  final AppDependencies dependencies;
  final OnTopSwitch onTopSwitch;

  @override
  Widget build(BuildContext context) {
    final EdgeInsets pagePadding = pagePaddingFor(LayoutSize.of(context));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: pagePadding.copyWith(bottom: 0),
          child: Align(
            alignment: Alignment.centerRight,
            child: KeepOnTopButton(onTopSwitch: onTopSwitch),
          ),
        ),
        Expanded(
          child: ListenableBuilder(
            listenable: Listenable.merge(<Listenable>[
              navigation,
              dependencies.taskRepository,
            ]),
            builder: _buildShownPage,
          ),
        ),
      ],
    );
  }

  Widget _buildShownPage(BuildContext context, Widget? _) {
    final AppRoute route = navigation.currentRoute;
    if (route is! RunPageRoute) {
      throw StateError('A run window shows only run pages');
    }
    if (!_isRunKept(route)) {
      return const AppPage(
        children: <Widget>[
          EmptyState(
            title: _deletedRunTitle,
            message: _deletedRunMessage,
            action: null,
          ),
        ],
      );
    }

    return buildRunApprovalPrompts(
      runId: route.runId,
      dependencies: dependencies,
      child: buildRunWindowPage(
        route: route,
        dependencies: dependencies,
        navigation: navigation,
      ),
    );
  }

  bool _isRunKept(RunPageRoute route) {
    try {
      dependencies.taskRepository.findRun(route.runId);
    } on RecordNotFound {
      return false;
    }
    return true;
  }
}
