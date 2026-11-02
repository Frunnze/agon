import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import '../support/random_inputs.dart';

const String _fakeAgentPath = 'test/real_stack/fake_agent/claude';
const String _changesFileName = 'CHANGES.md';
const String _recordsVariable = 'AGENT_RECORDS';
const int _mostRepositories = 4;

List<Directory> _createRepositories(Directory parent, Random random) {
  final int count = 1 + random.nextInt(_mostRepositories);
  final List<Directory> repositories = <Directory>[];
  for (int index = 0; index < count; index += 1) {
    final Directory repository = Directory('${parent.path}/repo$index')
      ..createSync(recursive: true);
    repositories.add(repository);
  }
  return repositories;
}

Future<ProcessResult> _runFakeAgent({
  required Directory workingDirectory,
  required Directory records,
}) {
  return Process.run(
    '${Directory.current.path}/$_fakeAgentPath',
    <String>['-p', 'Do the work.'],
    workingDirectory: workingDirectory.path,
    environment: <String, String>{_recordsVariable: records.path},
  );
}

bool _hasChangesFile(Directory repository) {
  return File('${repository.path}/$_changesFileName').existsSync();
}

void main() {
  test(
    'test_fake_agent_property_writes_only_inside_its_test_folder',
    () async {
      final Random random = seededRandom(7901);

      for (int i = 0; i < propertyIterations ~/ 10; i += 1) {
        final Directory testFolder = Directory.systemTemp.createTempSync(
          'fake_agent_guard_',
        );
        final Directory outsideFolder = Directory.systemTemp.createTempSync(
          'fake_agent_outside_',
        );
        addTearDown(() => testFolder.deleteSync(recursive: true));
        addTearDown(() => outsideFolder.deleteSync(recursive: true));
        final Directory records = Directory('${testFolder.path}/records')
          ..createSync();
        final Directory taskFolder = Directory(
          '${testFolder.path}/runner/task',
        )..createSync(recursive: true);

        final List<Directory> insideRepositories = _createRepositories(
          taskFolder,
          random,
        );
        final List<Directory> outsideRepositories = _createRepositories(
          outsideFolder,
          random,
        );

        final ProcessResult outsideRun = await _runFakeAgent(
          workingDirectory: outsideFolder,
          records: records,
        );
        final ProcessResult insideRun = await _runFakeAgent(
          workingDirectory: taskFolder,
          records: records,
        );

        expect(outsideRun.exitCode, isNot(0));
        expect(outsideRepositories.where(_hasChangesFile), isEmpty);
        expect(insideRun.exitCode, 0, reason: '${insideRun.stdout}');
        expect(insideRepositories.every(_hasChangesFile), isTrue);
      }
    },
  );
}
