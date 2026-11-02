import 'package:flutter/material.dart';

import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/data/rules/repository_address.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';
import 'package:agent_orchestration/screens/projects.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/app_dialog.dart';
import 'package:agent_orchestration/widgets/fact_list.dart';
import 'package:agent_orchestration/widgets/forms/choice_list_field.dart';
import 'package:agent_orchestration/widgets/forms/form_field_block.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

Future<void> showAddRepositoryDialog({
  required BuildContext context,
  required Project project,
  required ProjectRepository projectRepository,
  required String confirmationMethodName,
}) {
  return showAppDialog<void>(
    context: context,
    builder: (BuildContext _) => AddRepositoryDialog(
      project: project,
      projectRepository: projectRepository,
      confirmationMethodName: confirmationMethodName,
    ),
  );
}

Future<void> showRemoveRepositoryDialog({
  required BuildContext context,
  required Project project,
  required Repository repository,
  required ProjectRepository projectRepository,
}) {
  return showAppDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => AppDialog(
      title: describeRepositoryPath(repository.address),
      content: <Widget>[
        FactList(
          facts: <Fact>[
            Fact(
              term: 'Address',
              description: <TextSegment>[
                TextSegment.monospace(repository.address),
              ],
            ),
            Fact(
              term: 'Branch',
              description: <TextSegment>[
                TextSegment.monospace(repository.defaultBranch),
              ],
            ),
            Fact(
              term: 'Agents can',
              description: <TextSegment>[
                TextSegment(describeAgentAccess(repository.agentAccess)),
              ],
            ),
          ],
        ),
      ],
      actions: <Widget>[
        AppButton.secondary(
          label: 'Close',
          onPressed: () => Navigator.of(dialogContext).pop(),
        ),
        AppButton.danger(
          label: 'Remove repo',
          onPressed: () async {
            await projectRepository.removeRepository(
              project.id,
              repository.address,
            );
            if (dialogContext.mounted) {
              Navigator.of(dialogContext).pop();
            }
          },
        ),
      ],
    ),
  );
}

class AddRepositoryDialog extends StatefulWidget {
  const AddRepositoryDialog({
    required this.project,
    required this.projectRepository,
    required this.confirmationMethodName,
    super.key,
  });

  final Project project;
  final ProjectRepository projectRepository;
  final String confirmationMethodName;

  @override
  State<AddRepositoryDialog> createState() => _AddRepositoryDialogState();
}

class _AddRepositoryDialogState extends State<AddRepositoryDialog> {
  final TextEditingController _addressController = TextEditingController();
  AgentAccess _access = AgentAccess.pushAfterApproval;
  String? _addressProblem;

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'Add repo to ${widget.project.name}',
      content: <Widget>[
        FormFieldBlock(
          label: 'Address',
          hint: 'Paste a GitHub address.',
          children: <Widget>[
            RepositoryEntryField(
              controller: _addressController,
              problem: _addressProblem,
              placeholder: 'github.com/acme/repo',
              onAdded: _addRepository,
            ),
          ],
        ),
        FormFieldBlock(
          label: 'What agents can do',
          children: <Widget>[
            ChoiceListField<AgentAccess>(
              options: buildAgentAccessChoices(
                confirmationMethodName: widget.confirmationMethodName,
              ),
              selected: _access,
              onChanged: (AgentAccess access) =>
                  setState(() => _access = access),
            ),
          ],
        ),
      ],
      actions: <Widget>[
        AppButton.secondary(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Future<void> _addRepository() async {
    final String text = _addressController.text;
    final List<String> addedAddresses = <String>[
      for (final Repository repository in widget.project.repositories)
        repository.address,
    ];
    final String? problem = describeRepositoryEntryProblem(
      text: text,
      addedAddresses: addedAddresses,
    );
    if (problem != null) {
      setState(() => _addressProblem = problem);
      return;
    }

    await widget.projectRepository.addRepository(
      widget.project.id,
      Repository(
        address: parseRepositoryAddress(text)!,
        defaultBranch: defaultRepositoryBranch,
        agentAccess: _access,
      ),
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}
