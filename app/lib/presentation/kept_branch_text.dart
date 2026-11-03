import 'package:agent_orchestration/data/rules/kept_branches.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

const String keptBranchesTitle =
    'The work stayed on its branch and was not pushed';

List<TextSegment> describeKeptBranch({
  required KeptBranch kept,
  required DeviceNames deviceNames,
}) {
  final String repository = describeRepositoryPath(kept.repositoryAddress);
  final String runnerName = deviceNames.nameOf(kept.runner);

  return <TextSegment>[
    TextSegment('The push to $repository was denied, so its commits stay on '),
    TextSegment.monospace(kept.branch),
    TextSegment(' on $runnerName.'),
  ];
}

String describeKeptBranchLink(KeptBranch kept) {
  final String repository = describeRepositoryPath(kept.repositoryAddress);

  return 'Browse the branch in $repository';
}
