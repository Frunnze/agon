import 'dart:async';

import 'package:flutter/material.dart';

import 'package:agent_orchestration/data/folder_picker.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';
import 'package:agent_orchestration/data/rules/local_folder_address.dart';
import 'package:agent_orchestration/data/rules/naming.dart';
import 'package:agent_orchestration/data/rules/repository_address.dart';
import 'package:agent_orchestration/presentation/approval_policy_text.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/problem_text.dart';
import 'package:agent_orchestration/screens/projects.dart';
import 'package:agent_orchestration/screens/projects/new_project_repos_field.dart';
import 'package:agent_orchestration/screens/shared/approval_policy_field.dart';
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
    this.onChanged,
  });

  final DraftedProject initialProject;
  final DeviceRepository deviceRepository;
  final FolderPicker? folderPicker;
  final List<FormAction<DraftedProject>> actions;
  final ValueChanged<DraftedProject>? onChanged;

  @override
  State<ProjectForm> createState() => _ProjectFormState();
}

class _ProjectFormState extends State<ProjectForm> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.initialProject.name,
  );
  final TextEditingController _addressController = TextEditingController();
  late List<RepositoryDraft> _repositories =
      widget.initialProject.repositories;
  late AgentAccess _access = widget.initialProject.agentAccess;
  late ApprovalPolicy? _approvalPolicy = widget.initialProject.approvalPolicy;
  Set<String> _gitStartedAddresses = const <String>{};
  String? _filledName;
  String? _nameProblem;
  String? _addressProblem;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  DraftedProject _readProject() {
    return DraftedProject(
      name: _nameController.text.trim(),
      repositories: _repositories,
      agentAccess: _access,
      approvalPolicy: _approvalPolicy,
    );
  }

  void _reportProject() {
    widget.onChanged?.call(_readProject());
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
              onChanged: _changeName,
            ),
          ],
        ),
        NewProjectReposField(
          drafts: _repositories,
          gitStartedAddresses: _gitStartedAddresses,
          deviceNames: deviceNames,
          addressController: _addressController,
          addressProblem: _addressProblem,
          onAddressChanged: (String _) =>
              setState(() => _addressProblem = null),
          onAddressAdded: () => unawaited(_addTypedRepository()),
          onFolderChosen: folderPicker == null
              ? null
              : () => unawaited(_chooseFolder(folderPicker)),
          onRemoved: _removeRepository,
        ),
        FormFieldBlock(
          label: 'What agents can do',
          children: <Widget>[
            ChoiceListField<AgentAccess>(
              options: buildAgentAccessChoices(),
              selected: _access,
              onChanged: _changeAccess,
            ),
          ],
        ),
        ApprovalPolicyField(
          fallback: ApprovalPolicyFallback.workspace,
          selected: _approvalPolicy,
          onChanged: _changeApprovalPolicy,
        ),
        FormActionButtons<DraftedProject>(
          actions: widget.actions,
          isSubmitting: _isSubmitting,
          onSubmit: (SubmitFormAction<DraftedProject> action) =>
              unawaited(_submit(action)),
        ),
      ],
    );
  }

  void _changeName(String _) {
    setState(() => _nameProblem = null);
    _reportProject();
  }

  void _changeAccess(AgentAccess access) {
    setState(() => _access = access);
    _reportProject();
  }

  void _changeApprovalPolicy(ApprovalPolicy? approvalPolicy) {
    setState(() => _approvalPolicy = approvalPolicy);
    _reportProject();
  }

  List<String> _listAddedAddresses() {
    return <String>[
      for (final RepositoryDraft repository in _repositories)
        repository.address,
    ];
  }

  Future<void> _addTypedRepository() async {
    final String text = _addressController.text;
    final bool isFolderPath =
        widget.folderPicker != null && looksLikeFolderPath(text);
    if (isFolderPath) {
      await _addFolder(text);
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
    final RepositoryDraft repository = RepositoryDraft(
      address: parseRepositoryAddress(text)!,
      defaultBranch: defaultRepositoryBranch,
    );
    _keepRepository(repository);
  }

  Future<void> _chooseFolder(FolderPicker folderPicker) async {
    final String? path = await folderPicker.chooseFolder();
    if (path == null) {
      return;
    }
    await _addFolder(path);
  }

  Future<void> _addFolder(String path) async {
    final CheckedFolder checked;
    try {
      checked = await widget.deviceRepository.checkLocalFolder(path);
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

    if (!mounted) {
      return;
    }
    final RepositoryDraft repository = checked.repository;
    if (_listAddedAddresses().contains(repository.address)) {
      setState(() => _addressProblem = repositoryAlreadyAddedProblem);
      return;
    }
    if (checked.hasStartedGit) {
      setState(() {
        _gitStartedAddresses = <String>{
          ..._gitStartedAddresses,
          repository.address,
        };
      });
    }
    _keepRepository(repository);
  }

  void _keepRepository(RepositoryDraft repository) {
    _addressController.clear();
    final bool isFirstRepository = _repositories.isEmpty;
    setState(() {
      if (isFirstRepository) {
        _fillNameFromFirstRepository(repository);
      }
      _repositories = List<RepositoryDraft>.unmodifiable(<RepositoryDraft>[
        ..._repositories,
        repository,
      ]);
      _addressProblem = null;
    });
    _reportProject();
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

  void _removeRepository(String address) {
    setState(() {
      _repositories = List<RepositoryDraft>.unmodifiable(
        _repositories.where(
          (RepositoryDraft repository) => repository.address != address,
        ),
      );
    });
    _reportProject();
  }

  Future<void> _submit(SubmitFormAction<DraftedProject> action) async {
    final DraftedProject project = _readProject();
    final String? nameProblem = describeNameProblem(project.name);
    final String? repositoryProblem = project.repositories.isEmpty
        ? _noRepositoryProblem
        : null;
    setState(() {
      _nameProblem = nameProblem;
      _addressProblem = repositoryProblem;
    });
    if (nameProblem != null || repositoryProblem != null) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await action.onSubmitted(project);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
