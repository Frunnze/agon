import 'package:flutter/material.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/forms/form_field_block.dart';

class StepNameField extends StatefulWidget {
  const StepNameField({
    required this.workflow,
    required this.agent,
    required this.onAgentChanged,
    super.key,
  });

  final Workflow workflow;
  final WorkflowAgent agent;
  final ValueChanged<WorkflowAgent> onAgentChanged;

  @override
  State<StepNameField> createState() => _StepNameFieldState();
}

class _StepNameFieldState extends State<StepNameField> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.agent.name,
  );
  String? _nameProblem;

  @override
  void didUpdateWidget(StepNameField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_nameProblem == null && _nameController.text != widget.agent.name) {
      _nameController.text = widget.agent.name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormFieldBlock(
      label: 'Name',
      children: <Widget>[
        TextField(
          controller: _nameController,
          autocorrect: false,
          style: AppTextStyles.body.merge(AppTextStyles.monospace),
          decoration: InputDecoration(errorText: _nameProblem),
          onChanged: _changeName,
        ),
      ],
    );
  }

  void _changeName(String name) {
    final String? problem = describeAgentNameProblem(
      workflow: widget.workflow,
      agent: widget.agent,
      name: name,
    );

    setState(() => _nameProblem = problem);
    if (problem == null) {
      widget.onAgentChanged(widget.agent.copyWith(name: name));
    }
  }
}
