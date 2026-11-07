import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/repository_file_values.dart'
    as node;
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../bridge/support/list_copy_properties.dart';
import '../../bridge/support/random_moments.dart';
import '../../bridge/support/random_typed_values.dart';
import '../../support/random_inputs.dart';
import 'support/domain_model_properties.dart';

const int _largestSafeInteger = 9007199254740991;
const int _commonEntrySizeSpan = 1 << 30;

RepositoryHolder _randomHolder(Random random) {
  return RepositoryHolder(
    deviceId: randomDeviceId(random),
    name: randomHostileText(random),
    lastSeen: randomPreciseMoment(random),
  );
}

List<RepositoryHolder> _randomHolders(Random random) {
  final List<RepositoryHolder> holders = <RepositoryHolder>[];
  final int count = random.nextInt(5);
  for (int i = 0; i < count; i += 1) {
    holders.add(_randomHolder(random));
  }
  return holders;
}

int? _randomEntrySize(Random random) {
  return pickOne<int?>(random, <int?>[
    null,
    0,
    _largestSafeInteger,
    random.nextInt(_commonEntrySizeSpan),
  ]);
}

FilesFromRunner _filesFromRunner({
  required Random random,
  required List<String> branches,
  required List<String> taskBranches,
}) {
  return FilesFromRunner(
    runnerId: randomDeviceId(random),
    runnerName: randomHostileText(random),
    branches: branches,
    taskBranches: taskBranches,
  );
}

void main() {
  testModelConstructorProperties(
    ModelConstructor<FilesFromRunner>(
      testNamePrefix: 'test_files_from_runner_constructor_property',
      seed: 691501,
      randomFieldValues: (Random random) => <Object?>[
        randomDeviceId(random),
        randomHostileText(random),
        randomHostileTexts(random),
        randomHostileTexts(random),
      ],
      construct: (ModelFieldValues fieldValues) => FilesFromRunner(
        runnerId: fieldValues[0]! as DeviceId,
        runnerName: fieldValues[1]! as String,
        branches: fieldValues[2]! as List<String>,
        taskBranches: fieldValues[3]! as List<String>,
      ),
      readFieldValues: (FilesFromRunner files) => <Object?>[
        files.runnerId,
        files.runnerName,
        files.branches,
        files.taskBranches,
      ],
    ),
  );

  testListCopyProperties(
    ListCopy<FilesFromRunner, String>(
      testNamePrefix: 'test_files_from_runner_constructor_property_branches',
      seed: 691511,
      buildElement: randomHostileText,
      construct: (Random random, List<String> branches) => _filesFromRunner(
        random: random,
        branches: branches,
        taskBranches: randomHostileTexts(random),
      ),
      readList: (FilesFromRunner files) => files.branches,
    ),
  );

  testListCopyProperties(
    ListCopy<FilesFromRunner, String>(
      testNamePrefix:
          'test_files_from_runner_constructor_property_task_branches',
      seed: 691521,
      buildElement: randomHostileText,
      construct: (Random random, List<String> taskBranches) =>
          _filesFromRunner(
            random: random,
            branches: randomHostileTexts(random),
            taskBranches: taskBranches,
          ),
      readList: (FilesFromRunner files) => files.taskBranches,
    ),
  );

  testModelConstructorProperties(
    ModelConstructor<FilesWithoutRunner>(
      testNamePrefix: 'test_files_without_runner_constructor_property',
      seed: 691531,
      randomFieldValues: (Random random) => <Object?>[_randomHolders(random)],
      construct: (ModelFieldValues fieldValues) => FilesWithoutRunner(
        holders: fieldValues[0]! as List<RepositoryHolder>,
      ),
      readFieldValues: (FilesWithoutRunner files) => <Object?>[files.holders],
    ),
  );

  testListCopyProperties(
    ListCopy<FilesWithoutRunner, RepositoryHolder>(
      testNamePrefix: 'test_files_without_runner_constructor_property_holders',
      seed: 691541,
      buildElement: _randomHolder,
      construct: (Random random, List<RepositoryHolder> holders) =>
          FilesWithoutRunner(holders: holders),
      readList: (FilesWithoutRunner files) => files.holders,
    ),
  );

  testModelConstructorProperties(
    ModelConstructor<RepositoryHolder>(
      testNamePrefix: 'test_repository_holder_constructor_property',
      seed: 691551,
      randomFieldValues: (Random random) => <Object?>[
        randomDeviceId(random),
        randomHostileText(random),
        randomPreciseMoment(random),
      ],
      construct: (ModelFieldValues fieldValues) => RepositoryHolder(
        deviceId: fieldValues[0]! as DeviceId,
        name: fieldValues[1]! as String,
        lastSeen: fieldValues[2]! as DateTime,
      ),
      readFieldValues: (RepositoryHolder holder) => <Object?>[
        holder.deviceId,
        holder.name,
        holder.lastSeen,
      ],
    ),
  );

  testModelConstructorProperties(
    ModelConstructor<RepositoryBranchLocation>(
      testNamePrefix: 'test_repository_branch_location_constructor_property',
      seed: 691561,
      randomFieldValues: (Random random) => <Object?>[
        randomProjectId(random),
        randomHostileText(random),
        randomDeviceId(random),
        randomHostileText(random),
      ],
      construct: (ModelFieldValues fieldValues) => RepositoryBranchLocation(
        projectId: fieldValues[0]! as ProjectId,
        repositoryAddress: fieldValues[1]! as String,
        runnerId: fieldValues[2]! as DeviceId,
        branch: fieldValues[3]! as String,
      ),
      readFieldValues: (RepositoryBranchLocation location) => <Object?>[
        location.projectId,
        location.repositoryAddress,
        location.runnerId,
        location.branch,
      ],
    ),
  );

  testModelConstructorProperties(
    ModelConstructor<RepositoryEntry>(
      testNamePrefix: 'test_repository_entry_constructor_property',
      seed: 691571,
      randomFieldValues: (Random random) => <Object?>[
        randomHostileText(random),
        pickOne(random, RepositoryEntryKind.values),
        _randomEntrySize(random),
      ],
      construct: (ModelFieldValues fieldValues) => RepositoryEntry(
        name: fieldValues[0]! as String,
        kind: fieldValues[1]! as RepositoryEntryKind,
        size: fieldValues[2] as int?,
      ),
      readFieldValues: (RepositoryEntry entry) => <Object?>[
        entry.name,
        entry.kind,
        entry.size,
      ],
    ),
  );

  testNodeEnumMappingProperties(
    const NodeEnumMapping<RepositoryEntryKind, node.RepositoryEntryKind>(
      testNamePrefix: 'test_repository_entry_kind_values_property',
      choices: RepositoryEntryKind.values,
      nodeChoices: node.RepositoryEntryKind.values,
      mapFromNode: mapRepositoryEntryKindFromNode,
    ),
  );
}
