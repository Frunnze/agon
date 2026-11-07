import 'dart:math';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/repository_files.dart';

import '../../../support/random_inputs.dart';

typedef ListedEntryView = ({String name, RepositoryEntryKind kind, int? size});

const String fileTestAddress = 'github.com/acme/app';
const String fileTestOtherAddress = 'github.com/acme/other';
const String fileTestSeparator = '/';
const int _largestFileCount = 9;
const int _largestDepth = 3;
const int _largestSize = 100000;

const List<String> _segmentWords = <String>[
  'src',
  'Src',
  'SRC',
  'auth',
  '.github',
  'README.md',
  'a.ts',
  'B.ts',
  'z',
  'café',
  'Ünïcødé',
  '\u{1F600}.txt',
  '\u{FF41}.txt',
  'with space',
];

RepositoryBranchLocation buildFileTestLocation(String address) {
  return RepositoryBranchLocation(
    projectId: const ProjectId('project'),
    repositoryAddress: address,
    runnerId: const DeviceId('runner'),
    branch: 'main',
  );
}

FilePreview randomFilePreview(Random random) {
  return pickOne<FilePreview>(random, <FilePreview>[
    TextFilePreview(randomText(random)),
    UnavailableFilePreview(pickOne(random, PreviewUnavailableReason.values)),
  ]);
}

String randomFilePath(Random random) {
  final List<String> segments = <String>[];
  final int depth = 1 + random.nextInt(_largestDepth);
  for (int i = 0; i < depth; i += 1) {
    segments.add(pickOne(random, _segmentWords));
  }
  return segments.join(fileTestSeparator);
}

List<String> listFolderPrefixes(String path) {
  final List<String> segments = path.split(fileTestSeparator);
  final List<String> prefixes = <String>[];
  for (int index = 1; index < segments.length; index += 1) {
    prefixes.add(segments.sublist(0, index).join(fileTestSeparator));
  }
  return prefixes;
}

List<FakeRepositoryFile> randomRepositoryFiles(
  Random random, {
  required String address,
}) {
  final Map<String, FakeRepositoryFile> byPath =
      <String, FakeRepositoryFile>{};
  final int count = 1 + random.nextInt(_largestFileCount);
  for (int i = 0; i < count; i += 1) {
    final String path = randomFilePath(random);
    byPath[path] = FakeRepositoryFile(
      repositoryAddress: address,
      path: path,
      size: random.nextInt(_largestSize),
      preview: randomFilePreview(random),
    );
  }

  final Set<String> folders = <String>{};
  for (final String path in byPath.keys) {
    folders.addAll(listFolderPrefixes(path));
  }
  return <FakeRepositoryFile>[
    for (final FakeRepositoryFile file in byPath.values)
      if (!folders.contains(file.path)) file,
  ];
}

String findParentFolder(String path) {
  final int separatorIndex = path.lastIndexOf(fileTestSeparator);
  if (separatorIndex < 0) {
    return '';
  }
  return path.substring(0, separatorIndex);
}

String findLastPart(String path) {
  final int separatorIndex = path.lastIndexOf(fileTestSeparator);
  return path.substring(separatorIndex + 1);
}

FakeFileRepository buildFileRepository(List<FakeRepositoryFile> files) {
  return FakeFileRepository(
    sources: const <String, RepositoryFileSource>{},
    files: files,
  );
}

List<String> describeEntryNames(List<RepositoryEntry> entries) {
  final List<String> names = <String>[];
  for (final RepositoryEntry entry in entries) {
    names.add(entry.name);
  }
  return names;
}

List<ListedEntryView> describeListedEntries(List<RepositoryEntry> entries) {
  final List<ListedEntryView> views = <ListedEntryView>[];
  for (final RepositoryEntry entry in entries) {
    views.add((name: entry.name, kind: entry.kind, size: entry.size));
  }
  return views;
}

List<String> listEveryFileTestFolder(List<FakeRepositoryFile> files) {
  final Set<String> folders = <String>{''};
  for (final FakeRepositoryFile file in files) {
    folders.addAll(listFolderPrefixes(file.path));
  }
  return folders.toList();
}

Future<List<RepositoryEntry>> listFileTestFolder(
  FakeFileRepository repository,
  String folder,
) {
  return repository.listFolder(
    location: buildFileTestLocation(fileTestAddress),
    folder: folder,
  );
}

int compareFileTestCodePoints(String first, String second) {
  final List<int> firstRunes = first.runes.toList();
  final List<int> secondRunes = second.runes.toList();
  final int sharedLength = min(firstRunes.length, secondRunes.length);
  for (int i = 0; i < sharedLength; i += 1) {
    final int difference = firstRunes[i] - secondRunes[i];
    if (difference != 0) {
      return difference;
    }
  }
  return firstRunes.length - secondRunes.length;
}
