import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/data/repository/rule_repository.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/scope_catalog.dart';
import 'package:agent_orchestration/presentation/scope_text.dart';
import 'package:agent_orchestration/screens/rules.dart';
import 'package:agent_orchestration/screens/shared/action_refusal.dart';
import 'package:agent_orchestration/screens/shared/scope_catalog_lookup.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/app_page.dart';
import 'package:agent_orchestration/widgets/empty_state.dart';
import 'package:agent_orchestration/widgets/forms/switch_field.dart';
import 'package:agent_orchestration/widgets/label_chip.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';
import 'package:agent_orchestration/widgets/lists/responsive_list.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/page_header.dart';
import 'package:agent_orchestration/widgets/split_layout.dart';

typedef RuleSwitch = Future<Rule> Function(RuleId ruleId);

class RulesScreen extends StatelessWidget {
  const RulesScreen({
    required this.ruleRepository,
    required this.workspaceRepository,
    required this.projectRepository,
    required this.navigation,
    super.key,
  });

  final RuleRepository ruleRepository;
  final WorkspaceRepository workspaceRepository;
  final ProjectRepository projectRepository;
  final AppNavigation navigation;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        ruleRepository,
        workspaceRepository,
        projectRepository,
      ]),
      builder: _buildPage,
    );
  }

  Widget _buildPage(BuildContext context, Widget? _) {
    final List<Rule> rules = ruleRepository.listRules();

    if (rules.isEmpty) {
      return AppPage(
        children: <Widget>[
          const PageHeader(title: 'Rules'),
          EmptyState(
            title: 'No rules yet',
            message:
                'Write what every agent must follow, like never pushing to '
                "main, and each run's AGENTS.md gets it.",
            action: _buildNewRuleButton(),
          ),
        ],
      );
    }

    final ScopeCatalog catalog = collectScopeCatalog(
      workspaceRepository: workspaceRepository,
      projectRepository: projectRepository,
    );
    final Workspace workspace = workspaceRepository.currentWorkspace();
    final List<Project> projects = projectRepository.listProjects(
      workspace.id,
    );
    final Widget ruleList = ResponsiveList.plain(
      rows: <ListRowData>[
        for (final Rule rule in rules) _buildRow(context, rule, catalog),
      ],
    );

    return AppPage(
      children: <Widget>[
        PageHeader(
          title: 'Rules',
          summary: const <TextSegment>[
            TextSegment(
              "Each run's AGENTS.md gets the rules for its project.",
            ),
          ],
          actions: <Widget>[_buildNewRuleButton()],
        ),
        if (projects.isEmpty)
          ruleList
        else
          SplitLayout(
            proportion: SplitProportion.wideStart,
            start: ruleList,
            end: AgentsMarkdownPreview(
              rules: rules,
              workspaceId: workspace.id,
              project: projects.first,
            ),
          ),
      ],
    );
  }

  Widget _buildNewRuleButton() {
    return AppButton.primary(
      label: 'New rule',
      icon: AppIconKind.plus,
      onPressed: () =>
          navigation.openRoute(const NewRuleRoute(presetProjectId: null)),
    );
  }

  ListRowData _buildRow(
    BuildContext context,
    Rule rule,
    ScopeCatalog catalog,
  ) {
    return ListRowData(
      key: ValueKey<RuleId>(rule.id),
      main: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(rule.title, style: AppTextStyles.bodyBold),
          const SizedBox(height: AppSpacing.space1),
          Text(rule.details, style: AppTextStyles.smallMuted),
          const SizedBox(height: AppSpacing.space1),
          ChipList(describeScopeChips(rule.scope, catalog)),
        ],
      ),
      end: SwitchToggle(
        semanticLabel: 'Use "${rule.title}"',
        value: rule.enabled,
        onChanged: (bool isEnabled) =>
            unawaited(_switchRule(context, rule: rule, isEnabled: isEnabled)),
      ),
      onTap: () => navigation.openRoute(RuleDetailRoute(rule.id)),
    );
  }

  Future<void> _switchRule(
    BuildContext context, {
    required Rule rule,
    required bool isEnabled,
  }) {
    final RuleSwitch switchRule = isEnabled
        ? ruleRepository.turnRuleOn
        : ruleRepository.turnRuleOff;

    return runShowingRefusal(
      context: context,
      title: rule.title,
      actionLabel: changeSettingLabel,
      action: () => switchRule(rule.id),
    );
  }
}
