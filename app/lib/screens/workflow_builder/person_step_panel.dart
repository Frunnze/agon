import 'package:flutter/material.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/field_padding.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/forms/form_field_block.dart';
import 'package:agent_orchestration/widgets/gaps.dart';

const String personStepPanelTitle = 'Person step';
const String questionLabel = 'Question';
const String removeStepLabel = 'Remove step';
const String _questionHint =
    'The run waits here until you answer. Each outcome on an outgoing '
    'connection becomes an answer button.';
const int _questionMinimumLines = 3;
const int _questionMaximumLines = 6;

class PersonStepPanel extends StatefulWidget {
  const PersonStepPanel({
    required this.workflow,
    required this.agent,
    required this.onAgentChanged,
    required this.onRemoved,
    required this.onDone,
    super.key,
  });

  final Workflow workflow;
  final WorkflowAgent agent;
  final ValueChanged<WorkflowAgent> onAgentChanged;
  final VoidCallback onRemoved;
  final VoidCallback onDone;

  @override
  State<PersonStepPanel> createState() => _PersonStepPanelState();
}

class _PersonStepPanelState extends State<PersonStepPanel> {
  late final TextEditingController _questionController = TextEditingController(
    text: widget.agent.task,
  );

  @override
  void didUpdateWidget(PersonStepPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_questionController.text != widget.agent.task) {
      _questionController.text = widget.agent.task;
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final WorkflowAgent agent = widget.agent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: spaceVertically(<Widget>[
        PanelHeading(title: personStepPanelTitle, onDone: widget.onDone),
        StepNameField(
          workflow: widget.workflow,
          agent: agent,
          onAgentChanged: widget.onAgentChanged,
        ),
        FormFieldBlock(
          label: questionLabel,
          hint: _questionHint,
          children: <Widget>[
            TextField(
              controller: _questionController,
              minLines: _questionMinimumLines,
              maxLines: _questionMaximumLines,
              decoration: const InputDecoration(
                hintText: 'What should you decide here?',
                contentPadding: multiLineFieldPadding,
              ),
              onChanged: (String question) =>
                  widget.onAgentChanged(agent.copyWith(task: question)),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: AppButton.secondary(
            label: removeStepLabel,
            onPressed: widget.onRemoved,
          ),
        ),
      ], AppSpacing.space4),
    );
  }
}
