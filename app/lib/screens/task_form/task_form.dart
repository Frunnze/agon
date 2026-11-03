import 'dart:async';

import 'package:flutter/material.dart';

import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/screens/shared/approval_policy_field.dart';
import 'package:agent_orchestration/screens/task_form/agent_place_field.dart';
import 'package:agent_orchestration/screens/task_form/folder_runner_notice.dart';
import 'package:agent_orchestration/screens/task_form/schedule_fields.dart';
import 'package:agent_orchestration/screens/task_form/task_form_action.dart';
import 'package:agent_orchestration/screens/task_form/task_form_options.dart';
import 'package:agent_orchestration/screens/task_form/task_form_values.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/field_padding.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/forms/check_field.dart';
import 'package:agent_orchestration/widgets/forms/form_field_block.dart';
import 'package:agent_orchestration/widgets/forms/select_field.dart';
import 'package:agent_orchestration/widgets/forms/tag_input_field.dart';

const int _detailsMinimumLines = 3;
const int _detailsMaximumLines = 8;

class TaskForm extends StatefulWidget {
  const TaskForm({
    required this.initialValues,
    required this.options,
    required this.repeatChoices,
    required this.actions,
    super.key,
    this.repeatHint,
  });

  final TaskFormValues initialValues;
  final TaskFormOptions options;
  final List<RepeatChoice> repeatChoices;
  final List<TaskFormAction> actions;
  final String? repeatHint;

  @override
  State<TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<TaskForm> {
  late TaskFormValues _values = widget.initialValues;
  late final TextEditingController _titleController = TextEditingController(
    text: widget.initialValues.title,
  );
  late final TextEditingController _detailsController = TextEditingController(
    text: widget.initialValues.details,
  );
  late final TextEditingController _timeController = TextEditingController(
    text: widget.initialValues.timeText,
  );
  bool _showsProblems = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _detailsController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  TaskFormValues _readValues() {
    return _values.copyWith(
      title: _titleController.text,
      details: _detailsController.text,
      timeText: _timeController.text,
    );
  }

  void _updateValues(TaskFormValues nextValues) {
    setState(() => _values = nextValues);
  }

  @override
  Widget build(BuildContext context) {
    final TaskFormValues current = _readValues();
    final String? titleProblem = _showsProblems
        ? current.describeTitleProblem()
        : null;
    final MissingFolderRunner? missingFolderRunner =
        widget.options.missingFolderRunners[_values.projectId];

    return FormColumn(
      children: <Widget>[
        FormFieldBlock(
          label: 'What should be done?',
          children: <Widget>[
            TextField(
              controller: _titleController,
              decoration: InputDecoration(errorText: titleProblem),
            ),
          ],
        ),
        FormFieldBlock(
          label: 'Details',
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
        FormFieldBlock(
          label: 'Project',
          children: <Widget>[
            SelectField<ProjectId>(
              value: _values.projectId,
              entries: widget.options.projects,
              onChanged: (ProjectId projectId) =>
                  _updateValues(_readValues().copyWith(projectId: projectId)),
            ),
            if (missingFolderRunner != null)
              FolderRunnerNotice(missing: missingFolderRunner),
          ],
        ),
        FormFieldBlock(
          label: 'Who does it',
          children: <Widget>[
            SelectField<TaskDoer>(
              value: _values.doer,
              entries: widget.options.doers,
              onChanged: (TaskDoer doer) =>
                  _updateValues(_readValues().copyWith(doer: doer)),
            ),
          ],
        ),
        FormFieldBlock(
          label: 'Runs on',
          hint: 'A workflow picks its own runners.',
          children: <Widget>[
            SelectField<RunnerTarget>(
              value: _values.runsOn,
              entries: widget.options.runners,
              onChanged: (RunnerTarget target) =>
                  _updateValues(_readValues().copyWith(runsOn: target)),
            ),
          ],
        ),
        AgentPlaceField(
          place: _values.agentPlace,
          onChanged: (AgentPlace place) =>
              _updateValues(_readValues().copyWith(agentPlace: place)),
        ),
        _buildSkillsField(),
        _buildApprovalField(),
        ScheduleFields(
          repeat: _values.repeat,
          repeatChoices: widget.repeatChoices,
          repeatHint: widget.repeatHint,
          weekday: _values.weekday,
          timeController: _timeController,
          timeProblem: _showsProblems ? current.describeTimeProblem() : null,
          onRepeatChanged: (RepeatChoice repeat) =>
              _updateValues(_readValues().copyWith(repeat: repeat)),
          onWeekdayChanged: (weekday) =>
              _updateValues(_readValues().copyWith(weekday: weekday)),
        ),
        Wrap(
          spacing: AppSpacing.space2,
          runSpacing: AppSpacing.space2,
          children: <Widget>[
            for (final TaskFormAction action in widget.actions)
              AppButton(
                label: action.label,
                tone: action.tone,
                icon: action.icon,
                onPressed: _isSubmitting ? null : () => _runAction(action),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSkillsField() {
    final List<String> chosenNames = widget.options.describeSkills(
      _values.skillIds,
    );

    return FormFieldBlock(
      label: 'Skills to use',
      hint: 'A workflow sets the skills of each of its agents.',
      children: <Widget>[
        TagInputField(
          tags: chosenNames,
          suggestions: <String>[
            for (final skill in widget.options.skills) skill.name,
          ],
          placeholder: 'Add a skill',
          onTagAdded: _addSkill,
          onTagRemoved: _removeSkill,
        ),
        CheckField(
          label: 'Also let the agent pick automatic skills',
          value: _values.usesAutomaticSkills,
          onChanged: (bool usesAutomaticSkills) => _updateValues(
            _readValues().copyWith(usesAutomaticSkills: usesAutomaticSkills),
          ),
        ),
      ],
    );
  }

  Widget _buildApprovalField() {
    return ApprovalPolicyField(
      selected: _values.approvalPolicy,
      onChanged: (ApprovalPolicy policy) =>
          _updateValues(_readValues().copyWith(approvalPolicy: policy)),
    );
  }

  void _addSkill(String skillName) {
    final SkillId skillId = widget.options.findSkillId(skillName);

    _updateValues(
      _readValues().copyWith(
        skillIds: <SkillId>[..._values.skillIds, skillId],
      ),
    );
  }

  void _removeSkill(String skillName) {
    final SkillId skillId = widget.options.findSkillId(skillName);
    final List<SkillId> remaining = _values.skillIds
        .where((SkillId candidate) => candidate != skillId)
        .toList();

    _updateValues(_readValues().copyWith(skillIds: remaining));
  }

  void _runAction(TaskFormAction action) {
    switch (action) {
      case LeaveFormAction(:final VoidCallback onPressed):
        onPressed();
      case SubmitFormAction():
        unawaited(_submit(action));
    }
  }

  Future<void> _submit(SubmitFormAction action) async {
    final TaskFormValues values = _readValues();
    if (!values.isValid) {
      setState(() => _showsProblems = true);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await action.onSubmitted(values);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
