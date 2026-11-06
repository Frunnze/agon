import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/repository_file_values.dart';

import '../../support/random_inputs.dart';
import 'random_typed_values.dart';
import 'random_wire_values.dart';

const int _largestListLength = 4;

FileRunner randomFileRunner(Random random) {
  return FileRunner(
    deviceId: randomDeviceId(random),
    name: randomText(random),
  );
}

RepositoryHolder randomRepositoryHolder(Random random) {
  return RepositoryHolder(
    deviceId: randomDeviceId(random),
    name: randomText(random),
    lastSeen: randomLocalMoment(random),
  );
}

List<RepositoryHolder> randomRepositoryHolders(Random random) {
  final int count = random.nextInt(_largestListLength);
  final List<RepositoryHolder> holders = <RepositoryHolder>[];
  for (int i = 0; i < count; i += 1) {
    holders.add(randomRepositoryHolder(random));
  }
  return holders;
}

RepositoryEntry randomRepositoryEntry(Random random) {
  final bool hasSize = random.nextBool();
  return RepositoryEntry(
    name: randomText(random),
    kind: pickOne(random, RepositoryEntryKind.values),
    size: hasSize ? randomWholeNumber(random) : null,
  );
}

List<RepositoryEntry> randomRepositoryEntries(Random random) {
  final int count = random.nextInt(_largestListLength);
  final List<RepositoryEntry> entries = <RepositoryEntry>[];
  for (int i = 0; i < count; i += 1) {
    entries.add(randomRepositoryEntry(random));
  }
  return entries;
}
