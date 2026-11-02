import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../bridge/support/random_file_json.dart';
import '../../bridge/support/random_typed_values.dart';
import '../../bridge/support/scripted_node_transport.dart';
import '../../support/random_inputs.dart';
import 'support/node_backed_harness.dart';

const String _notFoundMessage = 'project 42 was not found';

final class _RecordingNode {
  _RecordingNode({required this.reply});

  final Object? reply;
  final List<JsonObject> commands = <JsonObject>[];

  String answer(String inputJson) {
    commands.add(decodeObject(jsonDecode(inputJson)));
    return encodeSuccessReply(reply);
  }
}

RepositoryBranchLocation _randomLocation(Random random) {
  return RepositoryBranchLocation(
    projectId: randomProjectId(random),
    repositoryAddress: randomText(random),
    runnerId: randomDeviceId(random),
    branch: randomText(random),
  );
}

void _expectLocationSent(
  JsonObject command,
  RepositoryBranchLocation location,
) {
  expect(command['project_id'], location.projectId.value);
  expect(command['repository_address'], location.repositoryAddress);
  expect(command['runner_id'], location.runnerId.value);
  expect(command['branch'], location.branch);
}

NodeBackedFileRepository _buildRepository(_RecordingNode recordingNode) {
  return NodeBackedFileRepository(
    channel: buildSimulatedChannel(recordingNode.answer),
  );
}

void main() {
  test('test_open_repository_property_sends_project_and_address', () async {
    final Random random = seededRandom(9701);
    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject reply = randomRepositoryBranchesJson(random);
      final _RecordingNode recordingNode = _RecordingNode(reply: reply);
      final ProjectId projectId = randomProjectId(random);
      final String address = randomText(random);

      final RepositoryFileSource source = await _buildRepository(recordingNode)
          .openRepository(projectId: projectId, repositoryAddress: address);

      final JsonObject command = recordingNode.commands.single;
      expect(command['command'], 'list_repository_branches');
      expect(command['project_id'], projectId.value);
      expect(command['repository_address'], address);
      expect(source is FilesFromRunner, reply['kind'] == 'available');
    }
  });

  test('test_list_folder_property_sends_location_and_folder', () async {
    final Random random = seededRandom(9702);
    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject reply = randomRepositoryFolderJson(random);
      final _RecordingNode recordingNode = _RecordingNode(reply: reply);
      final RepositoryBranchLocation location = _randomLocation(random);
      final String folder = randomText(random);

      final List<RepositoryEntry> entries = await _buildRepository(
        recordingNode,
      ).listFolder(location: location, folder: folder);

      final JsonObject command = recordingNode.commands.single;
      expect(command['command'], 'list_repository_files');
      _expectLocationSent(command, location);
      expect(command['folder'], folder);
      final List<Object?> wireEntries = reply['entries']! as List<Object?>;
      expect(entries.length, wireEntries.length);
    }
  });

  test('test_read_file_property_sends_location_and_path', () async {
    final Random random = seededRandom(9703);
    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject reply = randomRepositoryFileJson(random);
      final _RecordingNode recordingNode = _RecordingNode(reply: reply);
      final RepositoryBranchLocation location = _randomLocation(random);
      final String path = randomText(random);

      final RepositoryFile file = await _buildRepository(recordingNode)
          .readFile(location: location, path: path);

      final JsonObject command = recordingNode.commands.single;
      expect(command['command'], 'read_repository_file');
      _expectLocationSent(command, location);
      expect(command['path'], path);
      expect(file.path, reply['path']);
      expect(file.size, reply['size']);
    }
  });

  test('test_read_file_property_node_refusal_raises_state_error', () async {
    final Random random = seededRandom(9704);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String reason = 'refused ${randomText(random)}';
      final NodeBackedFileRepository repository = NodeBackedFileRepository(
        channel: buildSimulatedChannel(
          (String inputJson) => encodeErrorReply(reason),
        ),
      );

      await expectLater(
        repository.readFile(location: _randomLocation(random), path: 'a'),
        throwsA(
          isA<StateError>().having(
            (StateError error) => error.message,
            'message',
            reason,
          ),
        ),
      );
    }
  });

  test('test_open_repository_property_unknown_project_is_not_found', () async {
    final NodeBackedFileRepository repository = NodeBackedFileRepository(
      channel: buildSimulatedChannel(
        (String inputJson) => encodeErrorReply(_notFoundMessage),
      ),
    );

    await expectLater(
      repository.openRepository(
        projectId: const ProjectId('42'),
        repositoryAddress: 'github.com/acme/app',
      ),
      throwsA(isA<RecordNotFound>()),
    );
  });
}
