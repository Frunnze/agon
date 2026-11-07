import 'dart:async';

import 'package:flutter/material.dart';

import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/presentation/scope_catalog.dart';
import 'package:agent_orchestration/screens/shared/action_refusal.dart';
import 'package:agent_orchestration/screens/shared/scope_fields.dart';
import 'package:agent_orchestration/screens/shared/scope_selection.dart';
import 'package:agent_orchestration/screens/skills/skill_name_problem.dart';
import 'package:agent_orchestration/screens/task_form/submit_refusal.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/theme/field_padding.dart';
import 'package:agent_orchestration/widgets/forms/choice_list_field.dart';
import 'package:agent_orchestration/widgets/forms/form_action.dart';
import 'package:agent_orchestration/widgets/forms/form_field_block.dart';

const int _instructionsMinimumLines = 6;
const int _instructionsMaximumLines = 16;
const String _emptySummaryProblem = 'Say what the skill does';
const String _emptyInstructionsProblem = 'Write the instructions';
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

final List<ChoiceOption<SkillImprovement>> _improvementChoices =
    <ChoiceOption<SkillImprovement>>[
      for (final SkillImprovement improvement in SkillImprovement.values)
        ChoiceOption<SkillImprovement>(
          value: improvement,
          title: improvement.label,
          detail: improvement.explanation,
        ),
    ];

String? _describeEmptyProblem(String text, String problem) {
  if (text.trim().isEmpty) {
    return problem;
  }
  return null;
}

class SkillForm extends StatefulWidget {
  const SkillForm({
    required this.initialSkill,
    required this.otherSkills,
    required this.catalog,
    required this.actions,
    super.key,
    this.onChanged,
  });

  final SkillDraft initialSkill;
  final List<Skill> otherSkills;
  final ScopeCatalog catalog;
  final List<FormAction<SkillDraft>> actions;
  final ValueChanged<SkillDraft>? onChanged;

  @override
  State<SkillForm> createState() => _SkillFormState();
}

class _SkillFormState extends State<SkillForm> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.initialSkill.name,
  );
  late final TextEditingController _summaryController = TextEditingController(
    text: widget.initialSkill.summary,
  );
  late final TextEditingController _instructionsController =
      TextEditingController(text: widget.initialSkill.instructions);
  late ScopeSelection _scope = ScopeSelection.fromScope(
    widget.initialSkill.scope,
  );
  late SkillUsage _usage = widget.initialSkill.usage;
  late SkillImprovement _improvement = widget.initialSkill.improvement;
  String? _nameProblem;
  String? _summaryProblem;
  String? _instructionsProblem;
  SubmitRefusal? _refusal;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _summaryController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  SkillDraft _readSkill() {
    return SkillDraft(
      name: _nameController.text,
      summary: _summaryController.text.trim(),
      instructions: _instructionsController.text,
      scope: _scope.toScope(),
      usage: _usage,
      improvement: _improvement,
    );
  }

  void _reportSkill() {
    widget.onChanged?.call(_readSkill());
  }

  @override
  Widget build(BuildContext context) {
    return FormColumn(
      children: <Widget>[
        FormFieldBlock(
          label: 'Name',
          children: <Widget>[
            TextField(
              controller: _nameController,
              style: _monospaceInput,
              decoration: InputDecoration(errorText: _nameProblem),
              onChanged: _changeName,
            ),
          ],
        ),
        FormFieldBlock(
          label: 'What it does',
          hint: 'Agents read this to decide when the skill fits.',
          children: <Widget>[
            TextField(
              controller: _summaryController,
              decoration: InputDecoration(errorText: _summaryProblem),
              onChanged: _changeSummary,
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
                errorText: _instructionsProblem,
              ),
              onChanged: _changeInstructions,
            ),
          ],
        ),
        ScopeFields(
          catalog: widget.catalog,
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
        FormFieldBlock(
          label: 'Agents may improve it',
          children: <Widget>[
            ChoiceListField<SkillImprovement>(
              options: _improvementChoices,
              selected: _improvement,
              onChanged: _changeImprovement,
            ),
          ],
        ),
        ?_buildRefusalBanner(),
        FormActionButtons<SkillDraft>(
          actions: widget.actions,
          isSubmitting: _isSubmitting,
          onSubmit: (SubmitFormAction<SkillDraft> action) =>
              unawaited(_submit(action)),
        ),
      ],
    );
  }

  void _changeName(String _) {
    setState(() => _nameProblem = null);
    _reportSkill();
  }

  void _changeSummary(String _) {
    setState(() => _summaryProblem = null);
    _reportSkill();
  }

  void _changeInstructions(String _) {
    setState(() => _instructionsProblem = null);
    _reportSkill();
  }

  void _changeScope(ScopeSelection scope) {
    setState(() => _scope = scope);
    _reportSkill();
  }

  void _changeUsage(SkillUsage usage) {
    setState(() => _usage = usage);
    _reportSkill();
  }

  void _changeImprovement(SkillImprovement improvement) {
    setState(() => _improvement = improvement);
    _reportSkill();
  }

  SubmitRefusalBanner? _buildRefusalBanner() {
    final SubmitRefusal? refusal = _refusal;
    if (refusal == null) {
      return null;
    }
    return SubmitRefusalBanner(refusal: refusal);
  }

  Future<void> _submit(SubmitFormAction<SkillDraft> action) async {
    final SkillDraft skill = _readSkill();
    final String? nameProblem = describeSkillNameProblem(
      name: skill.name,
      existingSkills: widget.otherSkills,
    );
    final String? summaryProblem = _describeEmptyProblem(
      skill.summary,
      _emptySummaryProblem,
    );
    final String? instructionsProblem = _describeEmptyProblem(
      skill.instructions,
      _emptyInstructionsProblem,
    );
    setState(() {
      _nameProblem = nameProblem;
      _summaryProblem = summaryProblem;
      _instructionsProblem = instructionsProblem;
      _refusal = null;
    });

    final bool hasProblem =
        nameProblem != null ||
        summaryProblem != null ||
        instructionsProblem != null;
    if (hasProblem) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final SubmitRefusal? refusal = await catchRefusal(
        actionLabel: action.label,
        action: () => action.onSubmitted(skill),
      );
      if (mounted) {
        setState(() => _refusal = refusal);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
