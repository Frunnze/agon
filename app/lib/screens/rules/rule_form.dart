import 'dart:async';

import 'package:flutter/material.dart';

import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/rules/unicode_white_space.dart';
import 'package:agent_orchestration/presentation/scope_catalog.dart';
import 'package:agent_orchestration/screens/shared/action_refusal.dart';
import 'package:agent_orchestration/screens/shared/scope_fields.dart';
import 'package:agent_orchestration/screens/shared/scope_selection.dart';
import 'package:agent_orchestration/screens/task_form/submit_refusal.dart';
import 'package:agent_orchestration/theme/field_padding.dart';
import 'package:agent_orchestration/widgets/forms/form_action.dart';
import 'package:agent_orchestration/widgets/forms/form_field_block.dart';

const int _detailsMinimumLines = 3;
const int _detailsMaximumLines = 8;
const String _emptyTitleProblem = 'Write the rule';

class RuleForm extends StatefulWidget {
  const RuleForm({
    required this.initialRule,
    required this.catalog,
    required this.actions,
    super.key,
    this.onChanged,
  });

  final RuleDraft initialRule;
  final ScopeCatalog catalog;
  final List<FormAction<RuleDraft>> actions;
  final ValueChanged<RuleDraft>? onChanged;

  @override
  State<RuleForm> createState() => _RuleFormState();
}

class _RuleFormState extends State<RuleForm> {
  late final TextEditingController _titleController = TextEditingController(
    text: widget.initialRule.title,
  );
  late final TextEditingController _detailsController = TextEditingController(
    text: widget.initialRule.details,
  );
  late ScopeSelection _scope = ScopeSelection.fromScope(
    widget.initialRule.scope,
  );
  String? _titleProblem;
  SubmitRefusal? _refusal;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  RuleDraft _readRule() {
    return RuleDraft(
      title: trimUnicodeWhiteSpace(_titleController.text),
      details: trimUnicodeWhiteSpace(_detailsController.text),
      scope: _scope.toScope(),
    );
  }

  void _reportRule() {
    widget.onChanged?.call(_readRule());
  }

  @override
  Widget build(BuildContext context) {
    return FormColumn(
      children: <Widget>[
        FormFieldBlock(
          label: 'Rule',
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
          hint: 'Agents read the rule and its details in AGENTS.md.',
          children: <Widget>[
            TextField(
              controller: _detailsController,
              minLines: _detailsMinimumLines,
              maxLines: _detailsMaximumLines,
              decoration: const InputDecoration(
                contentPadding: multiLineFieldPadding,
              ),
              onChanged: (String _) => _reportRule(),
            ),
          ],
        ),
        ScopeFields(
          catalog: widget.catalog,
          selection: _scope,
          onChanged: _changeScope,
        ),
        ?_buildRefusalBanner(),
        FormActionButtons<RuleDraft>(
          actions: widget.actions,
          isSubmitting: _isSubmitting,
          onSubmit: (SubmitFormAction<RuleDraft> action) =>
              unawaited(_submit(action)),
        ),
      ],
    );
  }

  void _changeTitle(String _) {
    setState(() => _titleProblem = null);
    _reportRule();
  }

  void _changeScope(ScopeSelection scope) {
    setState(() => _scope = scope);
    _reportRule();
  }

  SubmitRefusalBanner? _buildRefusalBanner() {
    final SubmitRefusal? refusal = _refusal;
    if (refusal == null) {
      return null;
    }
    return SubmitRefusalBanner(refusal: refusal);
  }

  Future<void> _submit(SubmitFormAction<RuleDraft> action) async {
    final RuleDraft rule = _readRule();
    final String? titleProblem = rule.title.isEmpty
        ? _emptyTitleProblem
        : null;
    setState(() {
      _titleProblem = titleProblem;
      _refusal = null;
    });
    if (titleProblem != null) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final SubmitRefusal? refusal = await catchRefusal(
        actionLabel: action.label,
        action: () => action.onSubmitted(rule),
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
