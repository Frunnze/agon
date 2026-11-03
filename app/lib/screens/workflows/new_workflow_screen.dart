import 'package:flutter/material.dart';

import 'package:agent_orchestration/data/models/workflow_draft.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/screens/new_items/item_request_view.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/field_padding.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/forms/form_field_block.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

const String newWorkflowTitle = 'New workflow';
const String workflowQuestion = 'What should this workflow do?';
const String workflowPromptHint =
    'An agent fills in everything else: the name, where it is available, '
    "the diagram and every agent's settings. You check it, then sign it.";
const String draftWorkflowLabel = 'Draft workflow';
const double _promptMaximumWidth = 512;
const int _descriptionMinimumLines = 4;
const int _descriptionMaximumLines = 8;

class NewWorkflowScreen extends StatefulWidget {
  const NewWorkflowScreen({required this.navigation, super.key});

  final AppNavigation navigation;

  @override
  State<NewWorkflowScreen> createState() => _NewWorkflowScreenState();
}

class _NewWorkflowScreenState extends State<NewWorkflowScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  String? _descriptionProblem;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BuilderPageLayout(
      top: <Widget>[
        PageHeader(
          title: newWorkflowTitle,
          backLink: BackLink(
            label: 'Workflows',
            onPressed: widget.navigation.closeRoute,
          ),
          actions: <Widget>[
            AppButton.secondary(
              label: 'Cancel',
              onPressed: widget.navigation.closeRoute,
            ),
          ],
        ),
      ],
      builder: CanvasFrame(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space4,
            vertical: AppSpacing.space6,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _promptMaximumWidth),
              child: _buildPrompt(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrompt() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        FormFieldBlock(
          label: workflowQuestion,
          hint: workflowPromptHint,
          children: <Widget>[
            TextField(
              controller: _descriptionController,
              minLines: _descriptionMinimumLines,
              maxLines: _descriptionMaximumLines,
              decoration: InputDecoration(
                contentPadding: multiLineFieldPadding,
                errorText: _descriptionProblem,
              ),
              onChanged: (String _) =>
                  setState(() => _descriptionProblem = null),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space3),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.space2,
          runSpacing: AppSpacing.space2,
          children: <Widget>[
            AppButton.primary(
              label: draftWorkflowLabel,
              icon: AppIconKind.draft,
              onPressed: _startDrafting,
            ),
            AppButton.secondary(
              label: addManuallyLabel,
              onPressed: () =>
                  widget.navigation.openRoute(const ManualWorkflowRoute()),
            ),
          ],
        ),
      ],
    );
  }

  void _startDrafting() {
    final String description = _descriptionController.text.trim();
    if (description.isEmpty) {
      setState(() => _descriptionProblem = blankWorkflowDescriptionProblem);
      return;
    }

    setState(() => _descriptionProblem = null);
    widget.navigation.openRoute(
      WorkflowDraftingRoute(WorkflowDraft(description: description)),
    );
  }
}
