import 'dart:async';

import 'package:flutter/material.dart';

import 'package:agent_orchestration/data/folder_picker.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/problem_text.dart';
import 'package:agent_orchestration/screens/projects/folder_choice.dart';
import 'package:agent_orchestration/screens/projects/project_text.dart';
import 'package:agent_orchestration/screens/projects/repository_rows.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/gaps.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';
import 'package:agent_orchestration/widgets/lists/responsive_list.dart';

const String _removeLabel = 'Remove';

typedef ChosenFoldersChanged = void Function(List<RepositoryDraft> folders);

class ChosenFolderField extends StatefulWidget {
  const ChosenFolderField({
    required this.folders,
    required this.folderPicker,
    required this.deviceRepository,
    required this.onChanged,
    super.key,
  });

  final List<RepositoryDraft> folders;
  final FolderPicker folderPicker;
  final DeviceRepository deviceRepository;
  final ChosenFoldersChanged onChanged;

  @override
  State<ChosenFolderField> createState() => _ChosenFolderFieldState();
}

class _ChosenFolderFieldState extends State<ChosenFolderField> {
  String? _problem;

  @override
  Widget build(BuildContext context) {
    final String? problem = _problem;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: spaceVertically(<Widget>[
        if (widget.folders.isNotEmpty) _buildFolderList(),
        Align(
          alignment: Alignment.centerLeft,
          child: AppButton.secondary(
            label: chooseFolderLabel,
            onPressed: () => unawaited(_chooseFolder()),
          ),
        ),
        if (problem != null)
          Text(
            problem,
            style: AppTextStyles.small.copyWith(color: AppColors.danger),
          ),
      ], AppSpacing.space2),
    );
  }

  Widget _buildFolderList() {
    final DeviceNames deviceNames = DeviceNames(
      widget.deviceRepository.listDevices(),
    );

    return ResponsiveList.plain(
      rows: <ListRowData>[
        for (final RepositoryDraft folder in widget.folders)
          buildRepositoryDraftRow(
            repository: folder,
            deviceNames: deviceNames,
            end: AppButton.secondary(
              label: _removeLabel,
              onPressed: () => _removeFolder(folder.address),
            ),
          ),
      ],
    );
  }

  Future<void> _chooseFolder() async {
    final String? path = await widget.folderPicker.chooseFolder();
    if (path == null) {
      return;
    }

    final RepositoryDraft folder;
    try {
      folder = await widget.deviceRepository.checkLocalFolder(path);
    } on Object catch (problem) {
      final String? explanation = describeProblemForPeople(problem);
      if (explanation == null) {
        rethrow;
      }
      if (mounted) {
        setState(() => _problem = explanation);
      }
      return;
    }

    if (!mounted) {
      return;
    }
    final bool isChosenAlready = widget.folders.any(
      (RepositoryDraft chosen) => chosen.address == folder.address,
    );
    if (isChosenAlready) {
      setState(() => _problem = repositoryAlreadyAddedProblem);
      return;
    }
    setState(() => _problem = null);
    widget.onChanged(<RepositoryDraft>[...widget.folders, folder]);
  }

  void _removeFolder(String address) {
    widget.onChanged(<RepositoryDraft>[
      for (final RepositoryDraft folder in widget.folders)
        if (folder.address != address) folder,
    ]);
  }
}
