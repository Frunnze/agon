import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/widgets/forms/select_entry.dart';

const String _branchesHeading = 'Branches';
const String _taskBranchesHeading = 'Task branches';

String? chooseInitialBranch({
  required FilesFromRunner source,
  required String? requestedBranch,
  required String defaultBranch,
}) {
  final List<String> listed = <String>[
    ...source.branches,
    ...source.taskBranches,
  ];
  if (listed.contains(requestedBranch)) {
    return requestedBranch;
  }
  if (listed.contains(defaultBranch)) {
    return defaultBranch;
  }
  if (listed.isEmpty) {
    return null;
  }
  return listed.first;
}

List<SelectEntry<String>> buildBranchEntries(FilesFromRunner source) {
  return <SelectEntry<String>>[
    ..._buildGroup(_branchesHeading, source.branches),
    ..._buildGroup(_taskBranchesHeading, source.taskBranches),
  ];
}

List<SelectEntry<String>> _buildGroup(String heading, List<String> branches) {
  if (branches.isEmpty) {
    return const <SelectEntry<String>>[];
  }
  return <SelectEntry<String>>[
    SelectGroupHeading<String>(heading),
    for (final String branch in branches)
      SelectOption<String>(value: branch, label: branch),
  ];
}
