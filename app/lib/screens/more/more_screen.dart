import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/app_page.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';
import 'package:agent_orchestration/widgets/lists/list_row_main.dart';
import 'package:agent_orchestration/widgets/lists/responsive_list.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({
    required this.workspaceRepository,
    required this.navigation,
    super.key,
  });

  final WorkspaceRepository workspaceRepository;
  final AppNavigation navigation;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: workspaceRepository,
      builder: _buildPage,
    );
  }

  Widget _buildPage(BuildContext context, Widget? _) {
    final String workspaceName = workspaceRepository.currentWorkspace().name;

    return AppPage(
      children: <Widget>[
        const PageHeader(title: 'More'),
        ResponsiveList.plain(
          rows: <ListRowData>[
            _buildRow(
              title: 'Workflows',
              subtitle: 'Reusable chains of agents',
              route: const SectionRoute(AppSection.workflows),
            ),
            _buildRow(
              title: 'Skills',
              subtitle: 'Instructions agents can follow',
              route: const SectionRoute(AppSection.skills),
            ),
            _buildRow(
              title: 'Rules',
              subtitle: 'What every agent must follow',
              route: const SectionRoute(AppSection.rules),
            ),
            _buildRow(
              title: 'Devices',
              subtitle: 'Runners, servers and pairing',
              route: const SectionRoute(AppSection.devices),
            ),
            _buildRow(
              title: 'Settings',
              subtitle: 'App server, commands, audit log',
              route: const SectionRoute(AppSection.settings),
            ),
            _buildRow(
              title: 'Switch workspace',
              subtitle: 'Now in $workspaceName',
              route: const WorkspaceSwitcherRoute(),
            ),
          ],
        ),
      ],
    );
  }

  ListRowData _buildRow({
    required String title,
    required String subtitle,
    required AppRoute route,
  }) {
    return ListRowData(
      main: ListRowMain(
        title: title,
        subtitle: <TextSegment>[TextSegment(subtitle)],
      ),
      end: const RowAction(),
      onTap: () => navigation.openRoute(route),
    );
  }
}
