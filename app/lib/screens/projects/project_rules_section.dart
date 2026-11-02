import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/rules/scope_rules.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/scope_catalog.dart';
import 'package:agent_orchestration/screens/projects.dart';
import 'package:agent_orchestration/screens/shared/muted_note.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';
import 'package:agent_orchestration/widgets/lists/list_row_main.dart';
import 'package:agent_orchestration/widgets/lists/responsive_list.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/page_section.dart';
import 'package:agent_orchestration/widgets/status_label.dart';

List<Rule> findProjectRules(List<Rule> rules, Project project) {
  return <Rule>[
    for (final Rule rule in rules)
      if (doesScopeApply(
        scope: rule.scope,
        workspaceId: project.workspaceId,
        projectId: project.id,
      ))
        rule,
  ];
}

class ProjectRulesSection extends StatelessWidget {
  const ProjectRulesSection({
    required this.project,
    required this.rules,
    required this.catalog,
    required this.navigation,
    super.key,
  });

  final Project project;
  final List<Rule> rules;
  final ScopeCatalog catalog;
  final AppNavigation navigation;

  @override
  Widget build(BuildContext context) {
    final List<Rule> projectRules = findProjectRules(rules, project);

    return PageSection(
      title: 'Rules',
      actions: <Widget>[
        AppButton.secondary(
          label: 'Add rule',
          icon: AppIconKind.plus,
          onPressed: () =>
              navigation.openRoute(NewRuleRoute(presetProjectId: project.id)),
        ),
      ],
      children: <Widget>[
        if (projectRules.isEmpty)
          const MutedNote('No rules apply to this project yet.')
        else
          ResponsiveList.plain(
            rows: <ListRowData>[
              for (final Rule rule in projectRules) _buildRow(rule),
            ],
          ),
      ],
    );
  }

  ListRowData _buildRow(Rule rule) {
    return ListRowData(
      key: ValueKey<String>(rule.id.value),
      main: ListRowMain(
        title: rule.title,
        subtitle: <TextSegment>[
          TextSegment(
            describeRuleReach(
              scope: rule.scope,
              project: project,
              catalog: catalog,
            ),
          ),
        ],
      ),
      end: StatusLabel(
        text: rule.enabled ? 'On' : 'Off',
        tone: StatusTone.muted,
      ),
      onTap: () =>
          navigation.openSection(const SectionRoute(AppSection.rules)),
    );
  }
}
