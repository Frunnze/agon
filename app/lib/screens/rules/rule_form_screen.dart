import 'dart:async';

import 'package:flutter/material.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/data/repository/rule_repository.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/screens/shared/scope_catalog_lookup.dart';
import 'package:agent_orchestration/screens/shared/scope_fields.dart';
import 'package:agent_orchestration/screens/shared/scope_selection.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/field_padding.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/app_page.dart';
import 'package:agent_orchestration/widgets/forms/form_field_block.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

const int _detailsMinimumLines = 3;
const int _detailsMaximumLines = 8;

ScopeSelection buildPresetRuleScope({
  required ProjectId? presetProjectId,
  required ProjectRepository projectRepository,
}) {
  if (presetProjectId == null) {
    return ScopeSelection.everywhere();
  }

  final Project project = projectRepository.findProject(presetProjectId);
  return ScopeSelection(
    workspaceIds: <WorkspaceId>[project.workspaceId],
    projectIds: <ProjectId>[project.id],
  );
}

class RuleFormScreen extends StatefulWidget {
  const RuleFormScreen({
    required this.existingRule,
    required this.presetProjectId,
    required this.ruleRepository,
    required this.workspaceRepository,
    required this.projectRepository,
    required this.navigation,
    super.key,
  });

  final Rule? existingRule;
  final ProjectId? presetProjectId;
  final RuleRepository ruleRepository;
  final WorkspaceRepository workspaceRepository;
  final ProjectRepository projectRepository;
  final AppNavigation navigation;

  @override
  State<RuleFormScreen> createState() => _RuleFormScreenState();
}

class _RuleFormScreenState extends State<RuleFormScreen> {
  late final TextEditingController _titleController = TextEditingController(
    text: widget.existingRule?.title,
  );
  late final TextEditingController _detailsController = TextEditingController(
    text: widget.existingRule?.details,
  );
  late ScopeSelection _scope = _buildInitialScope();
  String? _titleProblem;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  ScopeSelection _buildInitialScope() {
    final Rule? rule = widget.existingRule;
    if (rule == null) {
      return buildPresetRuleScope(
        presetProjectId: widget.presetProjectId,
        projectRepository: widget.projectRepository,
      );
    }
    return ScopeSelection.fromScope(rule.scope);
  }

  String? _findTitleProblem() {
    if (_titleController.text.trim().isEmpty) {
      return 'Write the rule';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final Rule? rule = widget.existingRule;

    return AppPage(
      children: <Widget>[
        PageHeader(
          title: rule == null ? 'New rule' : 'Edit rule',
          backLink: BackLink(
            label: rule == null ? 'Rules' : rule.title,
            onPressed: widget.navigation.closeRoute,
          ),
        ),
        FormColumn(
          children: <Widget>[
            FormFieldBlock(
              label: 'Rule',
              children: <Widget>[
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(errorText: _titleProblem),
                  onChanged: (String _) =>
                      setState(() => _titleProblem = null),
                ),
              ],
            ),
            FormFieldBlock(
              label: 'Details',
              hint: 'Agents read the rule and its details in AGENTS.md.',
              children: <Widget>[
                TextField(
                  controller: _detailsController,
                  minLines: _detailsMinimumLines,
                  maxLines: _detailsMaximumLines,
                  decoration: const InputDecoration(
                    contentPadding: multiLineFieldPadding,
                  ),
                ),
              ],
            ),
            ScopeFields(
              catalog: collectScopeCatalog(
                workspaceRepository: widget.workspaceRepository,
                projectRepository: widget.projectRepository,
              ),
              selection: _scope,
              onChanged: _changeScope,
            ),
            Wrap(
              spacing: AppSpacing.space2,
              runSpacing: AppSpacing.space2,
              children: <Widget>[
                AppButton.secondary(
                  label: 'Cancel',
                  onPressed: widget.navigation.closeRoute,
                ),
                AppButton.primary(
                  label: rule == null ? 'Add rule' : 'Save rule',
                  onPressed: _isSaving ? null : () => unawaited(_save()),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  void _changeScope(ScopeSelection scope) {
    setState(() => _scope = scope);
  }

  Future<void> _save() async {
    final String? titleProblem = _findTitleProblem();
    setState(() => _titleProblem = titleProblem);
    if (titleProblem != null) {
      return;
    }

    setState(() => _isSaving = true);
    final RuleDraft draft = RuleDraft(
      title: _titleController.text.trim(),
      details: _detailsController.text.trim(),
      scope: _scope.toScope(),
    );
    await _storeRule(draft);
    widget.navigation.closeSavedForm();
  }

  Future<Rule> _storeRule(RuleDraft draft) {
    final Rule? rule = widget.existingRule;
    if (rule == null) {
      return widget.ruleRepository.createRule(draft);
    }
    return widget.ruleRepository.updateRule(rule.id, draft);
  }
}
