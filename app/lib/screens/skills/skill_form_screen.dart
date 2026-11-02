import 'dart:async';

import 'package:flutter/material.dart';

import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/data/repository/skill_repository.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/screens/shared/scope_catalog_lookup.dart';
import 'package:agent_orchestration/screens/shared/scope_fields.dart';
import 'package:agent_orchestration/screens/shared/scope_selection.dart';
import 'package:agent_orchestration/screens/skills/skill_name_problem.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/field_padding.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/app_page.dart';
import 'package:agent_orchestration/widgets/forms/choice_list_field.dart';
import 'package:agent_orchestration/widgets/forms/form_field_block.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

const int _instructionsMinimumLines = 6;
const int _instructionsMaximumLines = 16;
final TextStyle _monospaceInput = AppTextStyles.body.merge(
  AppTextStyles.monospace,
);

const List<ChoiceOption<SkillUsage>> _usageChoices =
    <ChoiceOption<SkillUsage>>[
      ChoiceOption<SkillUsage>(
        value: SkillUsage.automatic,
        title: 'Automatic',
        detail: 'Any agent can use it when the work fits.',
      ),
      ChoiceOption<SkillUsage>(
        value: SkillUsage.whenChosen,
        title: 'Only when chosen',
        detail: 'A task, job or workflow agent has to add it.',
      ),
    ];

class SkillFormScreen extends StatefulWidget {
  const SkillFormScreen({
    required this.existingSkill,
    required this.skillRepository,
    required this.workspaceRepository,
    required this.projectRepository,
    required this.navigation,
    super.key,
  });

  final Skill? existingSkill;
  final SkillRepository skillRepository;
  final WorkspaceRepository workspaceRepository;
  final ProjectRepository projectRepository;
  final AppNavigation navigation;

  @override
  State<SkillFormScreen> createState() => _SkillFormScreenState();
}

class _SkillFormScreenState extends State<SkillFormScreen> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.existingSkill?.name,
  );
  late final TextEditingController _summaryController = TextEditingController(
    text: widget.existingSkill?.summary,
  );
  late final TextEditingController _instructionsController =
      TextEditingController(text: widget.existingSkill?.instructions);
  late ScopeSelection _scope = _buildInitialScope();
  late SkillUsage _usage = widget.existingSkill?.usage ?? SkillUsage.automatic;
  bool _showsProblems = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _summaryController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  ScopeSelection _buildInitialScope() {
    final Skill? skill = widget.existingSkill;
    if (skill == null) {
      return ScopeSelection.everywhere();
    }
    return ScopeSelection.fromScope(skill.scope);
  }

  String? _findNameProblem() {
    final List<Skill> otherSkills = <Skill>[
      for (final Skill skill in widget.skillRepository.listSkills())
        if (skill.id != widget.existingSkill?.id) skill,
    ];
    return describeSkillNameProblem(
      name: _nameController.text,
      existingSkills: otherSkills,
    );
  }

  String? _findSummaryProblem() {
    if (_summaryController.text.trim().isEmpty) {
      return 'Say what the skill does';
    }
    return null;
  }

  String? _findInstructionsProblem() {
    if (_instructionsController.text.trim().isEmpty) {
      return 'Write the instructions';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final Skill? skill = widget.existingSkill;

    return AppPage(
      children: <Widget>[
        PageHeader(
          title: skill == null ? 'New skill' : 'Edit skill',
          backLink: BackLink(
            label: skill == null ? 'Skills' : skill.name,
            onPressed: widget.navigation.closeRoute,
          ),
        ),
        FormColumn(
          children: <Widget>[
            FormFieldBlock(
              label: 'Name',
              children: <Widget>[
                TextField(
                  controller: _nameController,
                  style: _monospaceInput,
                  decoration: InputDecoration(
                    errorText: _showsProblems ? _findNameProblem() : null,
                  ),
                ),
              ],
            ),
            FormFieldBlock(
              label: 'What it does',
              hint: 'Agents read this to decide when the skill fits.',
              children: <Widget>[
                TextField(
                  controller: _summaryController,
                  decoration: InputDecoration(
                    errorText: _showsProblems ? _findSummaryProblem() : null,
                  ),
                ),
              ],
            ),
            FormFieldBlock(
              label: 'Instructions',
              children: <Widget>[
                TextField(
                  controller: _instructionsController,
                  style: _monospaceInput,
                  minLines: _instructionsMinimumLines,
                  maxLines: _instructionsMaximumLines,
                  decoration: InputDecoration(
                    contentPadding: multiLineFieldPadding,
                    errorText: _showsProblems
                        ? _findInstructionsProblem()
                        : null,
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
            FormFieldBlock(
              label: 'When agents use it',
              children: <Widget>[
                ChoiceListField<SkillUsage>(
                  options: _usageChoices,
                  selected: _usage,
                  onChanged: _changeUsage,
                ),
              ],
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
                  label: 'Save skill',
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

  void _changeUsage(SkillUsage usage) {
    setState(() => _usage = usage);
  }

  Future<void> _save() async {
    final bool hasProblem =
        _findNameProblem() != null ||
        _findSummaryProblem() != null ||
        _findInstructionsProblem() != null;
    if (hasProblem) {
      setState(() => _showsProblems = true);
      return;
    }

    setState(() => _isSaving = true);
    final SkillDraft draft = SkillDraft(
      name: _nameController.text,
      summary: _summaryController.text.trim(),
      instructions: _instructionsController.text,
      scope: _scope.toScope(),
      usage: _usage,
    );
    await _storeSkill(draft);
    widget.navigation.closeRoute();
  }

  Future<Skill> _storeSkill(SkillDraft draft) {
    final Skill? skill = widget.existingSkill;
    if (skill == null) {
      return widget.skillRepository.createSkill(draft);
    }
    return widget.skillRepository.updateSkill(skill.id, draft);
  }
}
