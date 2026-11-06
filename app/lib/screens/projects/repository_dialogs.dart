import 'dart:async';

import 'package:flutter/material.dart';

import 'package:agent_orchestration/data/folder_picker.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/data/rules/local_folder_address.dart';
import 'package:agent_orchestration/data/rules/repository_address.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';
import 'package:agent_orchestration/presentation/problem_text.dart';
import 'package:agent_orchestration/screens/projects.dart';
import 'package:agent_orchestration/screens/projects/folder_choice.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/app_dialog.dart';
import 'package:agent_orchestration/widgets/fact_list.dart';
import 'package:agent_orchestration/widgets/forms/choice_list_field.dart';
import 'package:agent_orchestration/widgets/forms/form_field_block.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

const String _computerAddressHint =
    'Paste a GitHub address or choose a folder on this computer.';
const String _phoneAddressHint = 'Paste a GitHub address.';

Future<void> showAddRepositoryDialog({
  required BuildContext context,
  required Project project,
  required ProjectRepository projectRepository,
  required DeviceRepository deviceRepository,
  required FolderPicker? folderPicker,
}) {
  return showAppDialog<void>(
    context: context,
    builder: (BuildContext _) => AddRepositoryDialog(
      project: project,
      projectRepository: projectRepository,
      deviceRepository: deviceRepository,
      folderPicker: folderPicker,
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
    required this.deviceRepository,
    required this.folderPicker,
    super.key,
  });

  final Project project;
  final ProjectRepository projectRepository;
  final DeviceRepository deviceRepository;
  final FolderPicker? folderPicker;

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
    final FolderPicker? folderPicker = widget.folderPicker;

    return AppDialog(
      title: 'Add repo to ${widget.project.name}',
      content: <Widget>[
        FormFieldBlock(
          label: 'Address',
          hint: folderPicker == null
              ? _phoneAddressHint
              : _computerAddressHint,
          children: <Widget>[
            RepositoryEntryField(
              controller: _addressController,
              problem: _addressProblem,
              placeholder: folderPicker == null
                  ? phoneRepositoryPlaceholder
                  : computerRepositoryPlaceholder,
              onChanged: (String _) => setState(() => _addressProblem = null),
              onAdded: () => unawaited(_addTypedRepository()),
            ),
            if (folderPicker != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: AppButton.secondary(
                  label: chooseFolderLabel,
                  onPressed: () => unawaited(_chooseFolder(folderPicker)),
                ),
              ),
          ],
        ),
        FormFieldBlock(
          label: 'What agents can do',
          children: <Widget>[
            ChoiceListField<AgentAccess>(
              options: buildAgentAccessChoices(),
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

  List<String> _listAddedAddresses() {
    return <String>[
      for (final Repository repository in widget.project.repositories)
        repository.address,
    ];
  }

  Future<void> _addTypedRepository() async {
    final String text = _addressController.text;
    final bool isFolderPath =
        widget.folderPicker != null && looksLikeFolderPath(text);
    if (isFolderPath) {
      await _addFolder(widget.deviceRepository.checkLocalFolder(text));
      return;
    }

    final String? problem = describeRepositoryEntryProblem(
      text: text,
      addedAddresses: _listAddedAddresses(),
    );
    if (problem != null) {
      setState(() => _addressProblem = problem);
      return;
    }

    final RepositoryDraft typedRepository = RepositoryDraft(
      address: parseRepositoryAddress(text)!,
      defaultBranch: defaultRepositoryBranch,
    );
    await _saveRepository(typedRepository);
  }

  Future<void> _chooseFolder(FolderPicker folderPicker) async {
    final String? path = await folderPicker.chooseFolder();
    if (path == null) {
      return;
    }
    await _addFolder(widget.deviceRepository.checkLocalFolder(path));
  }

  Future<void> _addFolder(Future<CheckedFolder> folderAnswer) async {
    final CheckedFolder checked;
    try {
      checked = await folderAnswer;
    } on Object catch (problem) {
      final String? explanation = describeProblemForPeople(problem);
      if (explanation == null) {
        rethrow;
      }
      if (mounted) {
        setState(() => _addressProblem = explanation);
      }
      return;
    }

    final RepositoryDraft folderRepository = checked.repository;
    final bool isAlreadyAdded = _listAddedAddresses().contains(
      folderRepository.address,
    );
    if (isAlreadyAdded) {
      if (mounted) {
        setState(() => _addressProblem = repositoryAlreadyAddedProblem);
      }
      return;
    }
    await _saveRepository(folderRepository);
  }

  Future<void> _saveRepository(RepositoryDraft repository) async {
    await widget.projectRepository.addRepository(
      widget.project.id,
      Repository(
        address: repository.address,
        defaultBranch: repository.defaultBranch,
        agentAccess: _access,
      ),
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}
