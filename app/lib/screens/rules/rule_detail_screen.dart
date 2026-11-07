import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/data/repository/rule_repository.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/scope_catalog.dart';
import 'package:agent_orchestration/presentation/scope_text.dart';
import 'package:agent_orchestration/presentation/time_phrases.dart';
import 'package:agent_orchestration/screens/shared/deletion_prompts.dart';
import 'package:agent_orchestration/screens/shared/deletion_review.dart';
import 'package:agent_orchestration/screens/shared/scope_catalog_lookup.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/app_page.dart';
import 'package:agent_orchestration/widgets/fact_list.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

const SectionRoute _rulesRoute = SectionRoute(AppSection.rules);

class RuleDetailScreen extends StatelessWidget {
  const RuleDetailScreen({
    required this.ruleId,
    required this.ruleRepository,
    required this.workspaceRepository,
    required this.projectRepository,
    required this.navigation,
    super.key,
  });

  final RuleId ruleId;
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
    final Rule rule = ruleRepository.findRule(ruleId);
    final ScopeCatalog catalog = collectScopeCatalog(
      workspaceRepository: workspaceRepository,
      projectRepository: projectRepository,
    );
    final String status = rule.enabled ? 'On' : 'Off';

    return AppPage(
      children: <Widget>[
        PageHeader(
          title: rule.title,
          backLink: BackLink(
            label: 'Rules',
            onPressed: () => navigation.returnTo(_rulesRoute),
          ),
          actions: <Widget>[
            AppButton.secondary(
              label: 'Delete',
              onPressed: () => unawaited(_reviewDeletion(context, rule)),
            ),
            AppButton.primary(
              label: 'Edit',
              icon: AppIconKind.edit,
              onPressed: () => navigation.openRoute(EditRuleRoute(rule.id)),
            ),
          ],
        ),
        FactList(
          facts: <Fact>[
            Fact(
              term: 'Details',
              description: <TextSegment>[TextSegment(rule.details)],
            ),
            Fact.chips(
              term: 'Applies to',
              chips: describeScopeChips(rule.scope, catalog),
            ),
            Fact(
              term: 'Status',
              description: <TextSegment>[TextSegment(status)],
            ),
            Fact(
              term: 'Added',
              description: <TextSegment>[
                TextSegment(formatCalendarDate(rule.addedAt)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _reviewDeletion(BuildContext context, Rule rule) {
    return reviewDeletion(
      context: context,
      prompt: describeRuleDeletion(rule),
      navigation: navigation,
      leavePage: () => navigation.returnTo(_rulesRoute),
      deleteRecord: () => ruleRepository.deleteRule(rule.id),
    );
  }
}
