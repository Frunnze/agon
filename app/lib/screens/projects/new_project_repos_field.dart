import 'package:flutter/material.dart';

import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/projects/folder_choice.dart';
import 'package:agent_orchestration/screens/projects/repository_entry_field.dart';
import 'package:agent_orchestration/screens/projects/repository_rows.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/forms/form_field_block.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';
import 'package:agent_orchestration/widgets/lists/responsive_list.dart';

const String _computerHint =
    'Paste a GitHub address or choose a folder on this computer. Add as '
    'many as needed.';
const String _phoneHint = 'Paste a GitHub address. Add as many as needed.';
const String _computerPlaceholder = 'github.com/acme/repo or /path/to/folder';
const String _phonePlaceholder = 'github.com/acme/repo';
const String _removeLabel = 'Remove';

class NewProjectReposField extends StatelessWidget {
  const NewProjectReposField({
    required this.drafts,
    required this.gitStartedAddresses,
    required this.deviceNames,
    required this.addressController,
    required this.addressProblem,
    required this.onAddressChanged,
    required this.onAddressAdded,
    required this.onFolderChosen,
    required this.onRemoved,
    super.key,
  });

  final List<RepositoryDraft> drafts;
  final Set<String> gitStartedAddresses;
  final DeviceNames deviceNames;
  final TextEditingController addressController;
  final String? addressProblem;
  final ValueChanged<String> onAddressChanged;
  final VoidCallback onAddressAdded;
  final VoidCallback? onFolderChosen;
  final ValueChanged<String> onRemoved;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? chooseFolder = onFolderChosen;

    return FormFieldBlock(
      label: 'Repos',
      hint: chooseFolder == null ? _phoneHint : _computerHint,
      children: <Widget>[
        if (drafts.isNotEmpty)
          ResponsiveList.plain(
            rows: <ListRowData>[
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
            ],
          ),
        RepositoryEntryField(
          controller: addressController,
          problem: addressProblem,
          onChanged: onAddressChanged,
          placeholder: chooseFolder == null
              ? _phonePlaceholder
              : _computerPlaceholder,
          onAdded: onAddressAdded,
        ),
        if (chooseFolder != null)
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton.secondary(
              label: chooseFolderLabel,
              onPressed: chooseFolder,
            ),
          ),
      ],
    );
  }
}
