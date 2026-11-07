import 'dart:async';

import 'package:flutter/material.dart';

import 'package:agent_orchestration/data/folder_picker.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';
import 'package:agent_orchestration/data/rules/local_folder_address.dart';
import 'package:agent_orchestration/data/rules/naming.dart';
import 'package:agent_orchestration/presentation/approval_policy_text.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/projects.dart';
import 'package:agent_orchestration/screens/projects/new_project_repos_field.dart';
import 'package:agent_orchestration/screens/projects/project_repositories_editor.dart';
import 'package:agent_orchestration/screens/shared/action_refusal.dart';
import 'package:agent_orchestration/screens/shared/approval_policy_field.dart';
import 'package:agent_orchestration/screens/task_form/submit_refusal.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/forms/choice_list_field.dart';
import 'package:agent_orchestration/widgets/forms/form_action.dart';
import 'package:agent_orchestration/widgets/forms/form_field_block.dart';

const String _noRepositoryProblem = 'Add at least one repo';

class ProjectForm extends StatefulWidget {
  const ProjectForm({
    required this.initialProject,
    required this.deviceRepository,
    required this.folderPicker,
    required this.actions,
    super.key,
  });

  final DraftedProject initialProject;
  final DeviceRepository deviceRepository;
  final FolderPicker? folderPicker;
  final List<FormAction<DraftedProject>> actions;

  @override
  State<ProjectForm> createState() => _ProjectFormState();
}

class _ProjectFormState extends State<ProjectForm> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.initialProject.name,
  );
  late final ProjectRepositoriesEditor _repositoriesEditor =
      ProjectRepositoriesEditor(
        initialRepositories: widget.initialProject.repositories,
        deviceRepository: widget.deviceRepository,
        folderPicker: widget.folderPicker,
        onFirstRepositoryKept: _fillNameFromFirstRepository,
      );
  late AgentAccess _access = widget.initialProject.agentAccess;
  late ApprovalPolicy? _approvalPolicy = widget.initialProject.approvalPolicy;
  String? _filledName;
  String? _nameProblem;
  SubmitRefusal? _refusal;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _repositoriesEditor.addListener(_showRepositoryChange);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _repositoriesEditor.dispose();
    super.dispose();
  }

  DraftedProject _readProject() {
    return DraftedProject(
      name: _nameController.text.trim(),
      repositories: _repositoriesEditor.repositories,
      agentAccess: _access,
      approvalPolicy: _approvalPolicy,
    );
  }

  @override
  Widget build(BuildContext context) {
    final FolderPicker? folderPicker = widget.folderPicker;
    final DeviceNames deviceNames = DeviceNames(
      widget.deviceRepository.listDevices(),
    );

    return FormColumn(
      children: <Widget>[
        FormFieldBlock(
          label: 'Name',
          children: <Widget>[
            TextField(
              controller: _nameController,
              autocorrect: false,
              style: AppTextStyles.body.merge(AppTextStyles.monospace),
              decoration: InputDecoration(errorText: _nameProblem),
              onChanged: (String _) => setState(() => _nameProblem = null),
            ),
          ],
        ),
        NewProjectReposField(
          drafts: _repositoriesEditor.repositories,
          newFolderPath: _describeNewFolderPath(),
          gitStartedAddresses: _repositoriesEditor.gitStartedAddresses,
          deviceNames: deviceNames,
          addressController: _repositoriesEditor.addressController,
          addressProblem: _repositoriesEditor.addressProblem,
          onAddressChanged: (String _) =>
              _repositoriesEditor.showAddressProblem(null),
          onAddressAdded: () =>
              unawaited(_repositoriesEditor.addTypedRepository()),
          localFolderActions: folderPicker == null
              ? null
              : _buildLocalFolderActions(folderPicker),
          onRemoved: _repositoriesEditor.removeRepository,
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
        ApprovalPolicyField(
          fallback: ApprovalPolicyFallback.workspace,
          selected: _approvalPolicy,
          onChanged: (ApprovalPolicy? approvalPolicy) =>
              setState(() => _approvalPolicy = approvalPolicy),
        ),
        ?_buildRefusalBanner(),
        FormActionButtons<DraftedProject>(
          actions: widget.actions,
          isSubmitting: _isSubmitting,
          onSubmit: (SubmitFormAction<DraftedProject> action) =>
              unawaited(_submit(action)),
        ),
      ],
    );
  }

  LocalFolderActions _buildLocalFolderActions(FolderPicker folderPicker) {
    return LocalFolderActions(
      onFolderChosen: () =>
          unawaited(_repositoriesEditor.chooseFolder(folderPicker)),
      onNewFolderStarted: () =>
          unawaited(_repositoriesEditor.chooseNewFolderPlace(folderPicker)),
      onNewFolderRemoved: _repositoriesEditor.dropNewFolder,
    );
  }

  String? _describeNewFolderPath() {
    final String? parent = _repositoriesEditor.newFolderParent;
    if (parent == null) {
      return null;
    }
    return '$parent/${_nameController.text.trim()}';
  }

  void _showRepositoryChange() {
    setState(() {});
  }

  void _fillNameFromFirstRepository(RepositoryDraft firstRepository) {
    final String currentName = _nameController.text;
    final bool isTypedName =
        currentName.isNotEmpty && currentName != _filledName;
    if (isTypedName) {
      return;
    }

    final String repositoryName = describeFolderName(firstRepository.address);
    final String filledName = convertToProjectName(repositoryName);
    _nameController.text = filledName;
    _filledName = filledName;
    _nameProblem = null;
  }

  Future<void> _planFirstRepositoryFolder() async {
    final FolderPicker? folderPicker = widget.folderPicker;
    if (folderPicker == null || !_repositoriesEditor.hasNoRepository) {
      return;
    }

    final String parent = await folderPicker.prepareNewProjectsFolder();
    _repositoriesEditor.planNewFolder(parent);
  }

  SubmitRefusalBanner? _buildRefusalBanner() {
    final SubmitRefusal? refusal = _refusal;
    if (refusal == null) {
      return null;
    }
    return SubmitRefusalBanner(refusal: refusal);
  }

  Future<void> _submitProject(SubmitFormAction<DraftedProject> action) async {
    final SubmitRefusal? refusal = await catchRefusal(
      actionLabel: action.label,
      action: () => action.onSubmitted(_readProject()),
    );
    if (mounted) {
      setState(() => _refusal = refusal);
    }
  }

  Future<void> _submit(SubmitFormAction<DraftedProject> action) async {
    final String name = _nameController.text.trim();
    final String? nameProblem = describeNameProblem(name);
    final bool canNameFirstRepository = widget.folderPicker != null;
    final String? repositoryProblem =
        _repositoriesEditor.hasNoRepository && !canNameFirstRepository
        ? _noRepositoryProblem
        : null;
    setState(() {
      _nameProblem = nameProblem;
      _refusal = null;
    });
    _repositoriesEditor.showAddressProblem(repositoryProblem);
    if (nameProblem != null || repositoryProblem != null) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _planFirstRepositoryFolder();
      final bool isNewFolderReady = await _repositoriesEditor.createNewFolder(
        name,
      );
      if (isNewFolderReady) {
        await _submitProject(action);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
