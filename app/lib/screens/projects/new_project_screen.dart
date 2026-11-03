import 'dart:async';

import 'package:flutter/material.dart';

import 'package:agent_orchestration/data/folder_picker.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/data/rules/local_folder_address.dart';
import 'package:agent_orchestration/data/rules/naming.dart';
import 'package:agent_orchestration/data/rules/repository_address.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/problem_text.dart';
import 'package:agent_orchestration/screens/projects.dart';
import 'package:agent_orchestration/screens/projects/new_project_repos_field.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/app_page.dart';
import 'package:agent_orchestration/widgets/forms/choice_list_field.dart';
import 'package:agent_orchestration/widgets/forms/form_field_block.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

class NewProjectScreen extends StatefulWidget {
  const NewProjectScreen({
    required this.projectRepository,
    required this.workspaceRepository,
    required this.deviceRepository,
    required this.folderPicker,
    required this.navigation,
    super.key,
  });

  final ProjectRepository projectRepository;
  final WorkspaceRepository workspaceRepository;
  final DeviceRepository deviceRepository;
  final FolderPicker? folderPicker;
  final AppNavigation navigation;

  @override
  State<NewProjectScreen> createState() => _NewProjectScreenState();
}

class _NewProjectScreenState extends State<NewProjectScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  List<RepositoryDraft> _drafts = const <RepositoryDraft>[];
  Set<String> _gitStartedAddresses = const <String>{};
  String? _filledName;
  AgentAccess _access = AgentAccess.pushAfterApproval;
  String? _nameProblem;
  String? _addressProblem;
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final FolderPicker? folderPicker = widget.folderPicker;
    final DeviceNames deviceNames = DeviceNames(
      widget.deviceRepository.listDevices(),
    );

    return AppPage(
      children: <Widget>[
        PageHeader(
          title: 'New project',
          backLink: BackLink(
            label: 'Projects',
            onPressed: widget.navigation.closeRoute,
          ),
        ),
        FormColumn(
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
              drafts: _drafts,
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
                  onChanged: (AgentAccess access) =>
                      setState(() => _access = access),
                ),
              ],
            ),
            Wrap(
              spacing: AppSpacing.space2,
              runSpacing: AppSpacing.space2,
              children: <Widget>[
                AppButton.secondary(
                  label: 'Cancel',
                  onPressed: widget.navigation.closeRoute,
                ),
                AppButton.primary(
                  label: 'Create project',
                  onPressed: _isCreating ? null : _createProject,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  List<String> _listAddedAddresses() {
    return <String>[
      for (final RepositoryDraft draft in _drafts) draft.address,
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
    final RepositoryDraft draft = RepositoryDraft(
      address: parseRepositoryAddress(text)!,
      defaultBranch: defaultRepositoryBranch,
    );
    _keepDraft(draft);
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
    final RepositoryDraft draft = checked.repository;
    if (_listAddedAddresses().contains(draft.address)) {
      setState(() => _addressProblem = repositoryAlreadyAddedProblem);
      return;
    }
    if (checked.hasStartedGit) {
      setState(() {
        _gitStartedAddresses = <String>{
          ..._gitStartedAddresses,
          draft.address,
        };
      });
    }
    _keepDraft(draft);
  }

  void _keepDraft(RepositoryDraft draft) {
    _addressController.clear();
    final bool isFirstRepository = _drafts.isEmpty;
    setState(() {
      if (isFirstRepository) {
        _fillNameFromFirstRepository(draft);
      }
      _drafts = List<RepositoryDraft>.unmodifiable(<RepositoryDraft>[
        ..._drafts,
        draft,
      ]);
      _addressProblem = null;
    });
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
      _drafts = List<RepositoryDraft>.unmodifiable(
        _drafts.where((RepositoryDraft draft) => draft.address != address),
      );
    });
  }

  Future<void> _createProject() async {
    final String name = _nameController.text.trim();
    final String? nameProblem = describeNameProblem(name);
    final String? repositoryProblem = _drafts.isEmpty
        ? 'Add at least one repo'
        : null;
    setState(() {
      _nameProblem = nameProblem;
      _addressProblem = repositoryProblem;
    });
    if (nameProblem != null || repositoryProblem != null) {
      return;
    }

    setState(() => _isCreating = true);
    final Project project = await widget.projectRepository.createProject(
      ProjectDraft(
        workspaceId: widget.workspaceRepository.currentWorkspace().id,
        name: name,
        repositories: <Repository>[
          for (final RepositoryDraft draft in _drafts)
            Repository(
              address: draft.address,
              defaultBranch: draft.defaultBranch,
              agentAccess: _access,
            ),
        ],
      ),
    );
    widget.navigation.replaceSavedForm(ProjectRoute(project.id));
  }
}
