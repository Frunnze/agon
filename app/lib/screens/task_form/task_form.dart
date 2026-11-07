import 'dart:async';

import 'package:flutter/material.dart';

import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/presentation/approval_policy_text.dart';
import 'package:agent_orchestration/screens/shared/action_refusal.dart';
import 'package:agent_orchestration/screens/shared/approval_policy_field.dart';
import 'package:agent_orchestration/screens/task_form/agent_place_field.dart';
import 'package:agent_orchestration/screens/task_form/folder_runner_notice.dart';
import 'package:agent_orchestration/screens/task_form/schedule_fields.dart';
import 'package:agent_orchestration/screens/task_form/sign_workflow_notice.dart';
import 'package:agent_orchestration/screens/task_form/submit_refusal.dart';
import 'package:agent_orchestration/screens/task_form/task_form_options.dart';
import 'package:agent_orchestration/screens/task_form/task_form_values.dart';
import 'package:agent_orchestration/screens/task_form/task_skills_field.dart';
import 'package:agent_orchestration/screens/task_form/workflow_to_sign.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/theme/field_padding.dart';
import 'package:agent_orchestration/widgets/forms/form_action.dart';
import 'package:agent_orchestration/widgets/forms/form_field_block.dart';
import 'package:agent_orchestration/widgets/forms/select_field.dart';

const int _detailsMinimumLines = 3;
const int _detailsMaximumLines = 8;

class TaskForm extends StatefulWidget {
  const TaskForm({
    required this.initialValues,
    required this.options,
    required this.repeatChoices,
    required this.actions,
    required this.onRouteOpened,
    super.key,
    this.repeatHint,
    this.onChanged,
  });

  final TaskFormValues initialValues;
  final TaskFormOptions options;
  final List<RepeatChoice> repeatChoices;
  final List<FormAction<TaskFormValues>> actions;
  final ValueChanged<AppRoute> onRouteOpened;
  final String? repeatHint;
  final ValueChanged<TaskFormValues>? onChanged;

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
  String? _titleProblem;
  String? _timeProblem;
  SubmitRefusal? _refusal;
  bool _isSubmitting = false;
  final GlobalKey _signNoticeKey = GlobalKey();

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
    widget.onChanged?.call(nextValues);
  }

  void _reportTypedValues() {
    widget.onChanged?.call(_readValues());
  }

  void _changeTitle(String _) {
    setState(() => _titleProblem = null);
    _reportTypedValues();
  }

  void _changeTime(String _) {
    setState(() => _timeProblem = null);
    _reportTypedValues();
  }

  @override
  Widget build(BuildContext context) {
    final MissingFolderRunner? missingFolderRunner =
        widget.options.missingFolderRunners[_values.projectId];
    final WorkflowToSign? workflowToSign = widget.options.findWorkflowToSign(
      _values.doer,
    );
    final SubmitRefusal? refusal = _refusal;

    return FormColumn(
      children: <Widget>[
        FormFieldBlock(
          label: 'What should be done?',
          children: <Widget>[
            TextField(
              controller: _titleController,
              decoration: InputDecoration(errorText: _titleProblem),
              onChanged: _changeTitle,
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
              onChanged: (String _) => _reportTypedValues(),
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
            if (workflowToSign != null)
              SignWorkflowNotice(
                key: _signNoticeKey,
                workflow: workflowToSign,
                onOpened: () => widget.onRouteOpened(workflowToSign.signRoute),
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
        TaskSkillsField(
          skillIds: _values.skillIds,
          usesAutomaticSkills: _values.usesAutomaticSkills,
          options: widget.options,
          onSkillsChanged: (List<SkillId> skillIds) =>
              _updateValues(_readValues().copyWith(skillIds: skillIds)),
          onAutomaticSkillsChanged: (bool usesAutomaticSkills) =>
              _updateValues(
                _readValues().copyWith(
                  usesAutomaticSkills: usesAutomaticSkills,
                ),
              ),
        ),
        _buildApprovalField(),
        ScheduleFields(
          repeat: _values.repeat,
          repeatChoices: widget.repeatChoices,
          repeatHint: widget.repeatHint,
          weekday: _values.weekday,
          timeController: _timeController,
          timeProblem: _timeProblem,
          onTimeChanged: _changeTime,
          onRepeatChanged: (RepeatChoice repeat) =>
              _updateValues(_readValues().copyWith(repeat: repeat)),
          onWeekdayChanged: (weekday) =>
              _updateValues(_readValues().copyWith(weekday: weekday)),
        ),
        if (refusal != null) SubmitRefusalBanner(refusal: refusal),
        FormActionButtons<TaskFormValues>(
          actions: widget.actions,
          isSubmitting: _isSubmitting,
          onSubmit: (SubmitFormAction<TaskFormValues> action) =>
              unawaited(_submit(action)),
        ),
      ],
    );
  }

  Widget _buildApprovalField() {
    return ApprovalPolicyField(
      fallback: ApprovalPolicyFallback.project,
      selected: _values.approvalPolicy,
      onChanged: (ApprovalPolicy? policy) =>
          _updateValues(_readValues().withApprovalPolicy(policy)),
    );
  }

  Future<void> _submit(SubmitFormAction<TaskFormValues> action) async {
    final TaskFormValues values = _readValues();
    setState(() {
      _titleProblem = values.describeTitleProblem();
      _timeProblem = values.describeTimeProblem();
      _refusal = null;
    });
    if (!values.isValid) {
      return;
    }
    if (widget.options.findWorkflowToSign(values.doer) != null) {
      unawaited(Scrollable.ensureVisible(_signNoticeKey.currentContext!));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final SubmitRefusal? refusal = await catchRefusal(
        actionLabel: action.label,
        action: () => action.onSubmitted(values),
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
