import 'package:flutter/material.dart';

import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/projects/folder_choice.dart';
import 'package:agent_orchestration/screens/projects/repository_entry_field.dart';
import 'package:agent_orchestration/screens/projects/repository_rows.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/forms/form_field_block.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';
import 'package:agent_orchestration/widgets/lists/responsive_list.dart';

const String createNewFolderLabel = 'Create a new folder';
const String _computerHint =
    'Paste a GitHub address, choose a folder on this computer or create a '
    'new one. Add as many as needed.';
const String _phoneHint = 'Paste a GitHub address. Add as many as needed.';
const String _computerPlaceholder = 'github.com/acme/repo or /path/to/folder';
const String _phonePlaceholder = 'github.com/acme/repo';
const String _removeLabel = 'Remove';

final class LocalFolderActions {
  const LocalFolderActions({
    required this.onFolderChosen,
    required this.onNewFolderStarted,
    required this.onNewFolderRemoved,
  });

  final VoidCallback onFolderChosen;
  final VoidCallback onNewFolderStarted;
  final VoidCallback onNewFolderRemoved;
}

class NewProjectReposField extends StatelessWidget {
  const NewProjectReposField({
    required this.drafts,
    required this.newFolderPath,
    required this.gitStartedAddresses,
    required this.deviceNames,
    required this.addressController,
    required this.addressProblem,
    required this.onAddressChanged,
    required this.onAddressAdded,
    required this.localFolderActions,
    required this.onRemoved,
    super.key,
  });

  final List<RepositoryDraft> drafts;
  final String? newFolderPath;
  final Set<String> gitStartedAddresses;
  final DeviceNames deviceNames;
  final TextEditingController addressController;
  final String? addressProblem;
  final ValueChanged<String> onAddressChanged;
  final VoidCallback onAddressAdded;
  final LocalFolderActions? localFolderActions;
  final ValueChanged<String> onRemoved;

  @override
  Widget build(BuildContext context) {
    final LocalFolderActions? folderActions = localFolderActions;
    final List<ListRowData> rows = _buildRows(folderActions);

    return FormFieldBlock(
      label: 'Repos',
      hint: folderActions == null ? _phoneHint : _computerHint,
      children: <Widget>[
        if (rows.isNotEmpty) ResponsiveList.plain(rows: rows),
        RepositoryEntryField(
          controller: addressController,
          problem: addressProblem,
          onChanged: onAddressChanged,
          placeholder: folderActions == null
              ? _phonePlaceholder
              : _computerPlaceholder,
          onAdded: onAddressAdded,
        ),
        if (folderActions != null)
          Wrap(
            spacing: AppSpacing.space2,
            runSpacing: AppSpacing.space2,
            children: <Widget>[
              AppButton.secondary(
                label: chooseFolderLabel,
                onPressed: folderActions.onFolderChosen,
              ),
              AppButton.secondary(
                label: createNewFolderLabel,
                onPressed: folderActions.onNewFolderStarted,
              ),
            ],
          ),
      ],
    );
  }

  List<ListRowData> _buildRows(LocalFolderActions? folderActions) {
    final String? plannedFolderPath = newFolderPath;
    final List<ListRowData> rows = <ListRowData>[
      for (final RepositoryDraft draft in drafts)
        buildRepositoryDraftRow(
          repository: draft,
          deviceNames: deviceNames,
          gitStartedAddresses: gitStartedAddresses,
          end: AppButton.secondary(
            label: _removeLabel,
            onPressed: () => onRemoved(draft.address),
          ),
        ),
    ];
    if (plannedFolderPath == null || folderActions == null) {
      return rows;
    }

    final ListRowData newFolderRow = buildNewFolderRow(
      folderPath: plannedFolderPath,
      end: AppButton.secondary(
        label: _removeLabel,
        onPressed: folderActions.onNewFolderRemoved,
      ),
    );
    return <ListRowData>[...rows, newFolderRow];
  }
}
