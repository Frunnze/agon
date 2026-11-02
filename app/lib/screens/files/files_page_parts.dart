import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/screens/files/file_pickers.dart';
import 'package:agent_orchestration/screens/files/file_source_status.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/widgets/gaps.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/page_header.dart';
import 'package:agent_orchestration/widgets/status_label.dart';

const String filesPageTitle = 'Files';
const String _filesPageSummary = 'Read only';

PageHeader buildFilesPageHeader({
  required String projectName,
  required VoidCallback onBack,
}) {
  return PageHeader(
    title: filesPageTitle,
    summary: const <TextSegment>[TextSegment(_filesPageSummary)],
    backLink: BackLink(label: projectName, onPressed: onBack),
  );
}

class FilesProblem extends StatelessWidget {
  const FilesProblem({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return StatusLabel(
      text: text,
      tone: StatusTone.danger,
      icon: AppIconKind.alert,
    );
  }
}

class FileTreeSection extends StatelessWidget {
  const FileTreeSection({
    required this.repositoryPicker,
    required this.branchPicker,
    required this.runnerName,
    required this.treeView,
    super.key,
  });

  final Widget repositoryPicker;
  final Widget? branchPicker;
  final String runnerName;
  final Widget? treeView;

  @override
  Widget build(BuildContext context) {
    final Widget? tree = treeView;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: spaceVertically(<Widget>[
        FilePickers(repository: repositoryPicker, branch: branchPicker),
        FileSourceStatus(runnerName: runnerName),
        ?tree,
      ], AppSpacing.space3),
    );
  }
}
