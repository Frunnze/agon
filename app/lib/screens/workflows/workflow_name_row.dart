import 'package:flutter/material.dart';

import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/forms/form_field_block.dart';

const String workflowNameLabel = 'Workflow name';
const String workflowNameHint =
    'Like feature-pipeline: lowercase, digits and dashes';
const double _sideBySideMinimumWidth = 640;

class WorkflowNameRow extends StatelessWidget {
  const WorkflowNameRow({
    required this.controller,
    required this.problem,
    required this.onChanged,
    required this.onAgentAdded,
    required this.onPersonStepAdded,
    super.key,
  });

  final TextEditingController controller;
  final String? problem;
  final ValueChanged<String> onChanged;
  final VoidCallback onAgentAdded;
  final VoidCallback onPersonStepAdded;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: _buildRow);
  }

  Widget _buildRow(BuildContext context, BoxConstraints limits) {
    final Widget nameField = TextField(
      controller: controller,
      style: AppTextStyles.body.merge(AppTextStyles.monospace),
      decoration: InputDecoration(
        hintText: workflowNameHint,
        hintMaxLines: 1,
        errorText: problem,
      ),
      onChanged: onChanged,
    );
    final Widget addButtons = AddStepButtons(
      onAgentAdded: onAgentAdded,
      onPersonStepAdded: onPersonStepAdded,
    );

    if (limits.maxWidth < _sideBySideMinimumWidth) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          FormFieldBlock(
            label: workflowNameLabel,
            children: <Widget>[nameField],
          ),
          const SizedBox(height: AppSpacing.space4),
          Align(alignment: Alignment.centerLeft, child: addButtons),
        ],
      );
    }

    return FormFieldBlock(
      label: workflowNameLabel,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: nameField),
            const SizedBox(width: AppSpacing.space3),
            addButtons,
          ],
        ),
      ],
    );
  }
}
