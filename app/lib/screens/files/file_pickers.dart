import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/widgets/forms/form_field_block.dart';
import 'package:agent_orchestration/widgets/forms/select_entry.dart';
import 'package:agent_orchestration/widgets/forms/select_field.dart';

const String repositoryPickerLabel = 'Repository';
const String branchPickerLabel = 'Branch';

class FilePickers extends StatelessWidget {
  const FilePickers({
    required this.repository,
    required this.branch,
    super.key,
  });

  final Widget repository;
  final Widget? branch;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: _buildColumns);
  }

  Widget _buildColumns(BuildContext context, BoxConstraints constraints) {
    final double widestRepository = constraints.maxWidth - AppSpacing.space3;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: widestRepository),
          child: IntrinsicWidth(child: repository),
        ),
        const SizedBox(width: AppSpacing.space3),
        Expanded(child: branch ?? const SizedBox()),
      ],
    );
  }
}

class RepositoryPicker extends StatelessWidget {
  const RepositoryPicker({
    required this.repositories,
    required this.chosenAddress,
    required this.onChosen,
    super.key,
  });

  final List<Repository> repositories;
  final String chosenAddress;
  final ValueChanged<String> onChosen;

  @override
  Widget build(BuildContext context) {
    return FormFieldBlock(
      label: repositoryPickerLabel,
      children: <Widget>[
        SelectField<String>(
          value: chosenAddress,
          entries: <SelectEntry<String>>[
            for (final Repository repository in repositories)
              SelectOption<String>(
                value: repository.address,
                label: describeRepositoryPath(repository.address),
              ),
          ],
          onChanged: onChosen,
        ),
      ],
    );
  }
}

class BranchPicker extends StatelessWidget {
  const BranchPicker({
    required this.entries,
    required this.chosenBranch,
    required this.onChosen,
    super.key,
  });

  final List<SelectEntry<String>> entries;
  final String chosenBranch;
  final ValueChanged<String> onChosen;

  @override
  Widget build(BuildContext context) {
    return FormFieldBlock(
      label: branchPickerLabel,
      children: <Widget>[
        SelectField<String>(
          value: chosenBranch,
          entries: entries,
          onChanged: onChosen,
        ),
      ],
    );
  }
}
