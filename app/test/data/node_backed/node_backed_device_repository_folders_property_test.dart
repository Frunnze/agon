import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../bridge/support/scripted_node_transport.dart';
import '../../support/random_inputs.dart';
import 'support/node_backed_harness.dart';

const List<String> _folderProblems = <String>[
  'the folder /x already exists, so choose another name or place',
  'the folder /y does not exist or this app cannot open it',
  'could not start git in the folder /z: denied',
];

final class _FolderNode {
  _FolderNode({required this.reply});

  final JsonObject reply;
  final List<JsonObject> commands = <JsonObject>[];

  NodeBackedDeviceRepository buildRepository() {
    return NodeBackedDeviceRepository(channel: buildSimulatedChannel(answer));
  }

  String answer(String inputJson) {
    commands.add(decodeObject(jsonDecode(inputJson)));
    return encodeSuccessReply(reply);
  }
}

JsonObject _randomCheckedFolderJson(Random random) {
  return <String, Object?>{
    'address': 'local:${randomText(random)}:${randomHostileText(random)}',
    'default_branch': randomHostileText(random),
    'has_started_git': random.nextBool(),
  };
}

void _expectFolderOfReply(CheckedFolder folder, JsonObject reply) {
  expect(folder.repository.address, reply['address']);
  expect(folder.repository.defaultBranch, reply['default_branch']);
  expect(folder.hasStartedGit, reply['has_started_git']);
}

void main() {
  test('test_check_local_folder_property_sends_the_path_as_typed', () async {
    final Random random = seededRandom(76901);
    for (int i = 0; i < propertyIterations; i += 1) {
      final _FolderNode folderNode = _FolderNode(
        reply: _randomCheckedFolderJson(random),
      );
      final String path = randomHostileText(random);

      await folderNode.buildRepository().checkLocalFolder(path);

      expect(folderNode.commands.single, <String, Object?>{
        'command': 'check_local_folder',
        'path': path,
      });
    }
  });

  test(
    'test_create_local_folder_property_sends_parent_and_name_as_typed',
    () async {
      final Random random = seededRandom(76902);
      for (int i = 0; i < propertyIterations; i += 1) {
        final _FolderNode folderNode = _FolderNode(
          reply: _randomCheckedFolderJson(random),
        );
        final String parent = randomHostileText(random);
        final String name = randomHostileText(random);

        await folderNode.buildRepository().createLocalFolder(
          parent: parent,
          name: name,
        );

        expect(folderNode.commands.single, <String, Object?>{
          'command': 'create_local_folder',
          'parent': parent,
          'name': name,
        });
      }
    },
  );

  test(
    'test_create_local_folder_property_node_problems_reach_people',
    () async {
      final Random random = seededRandom(76903);
      for (int i = 0; i < propertyIterations; i += 1) {
        final String problem = pickOne(random, _folderProblems);
        final NodeBackedDeviceRepository repository =
            NodeBackedDeviceRepository(
              channel: buildSimulatedChannel(
                (String inputJson) => encodeErrorReply(problem),
              ),
            );

        await expectLater(
          repository.createLocalFolder(parent: '/p', name: randomText(random)),
          throwsA(
            isA<StateError>().having(
              (StateError error) => error.message,
              'message',
              problem,
            ),
          ),
        );
      }
    },
  );

  test('test_map_checked_folder_property_keeps_every_field', () async {
    final Random random = seededRandom(76904);
    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject reply = _randomCheckedFolderJson(random);
      final _FolderNode folderNode = _FolderNode(reply: reply);

      final CheckedFolder checked = await folderNode
          .buildRepository()
          .checkLocalFolder(randomText(random));

      _expectFolderOfReply(checked, reply);
    }
  });

  test('test_map_checked_folder_property_check_and_create_agree', () async {
    final Random random = seededRandom(76905);
    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject reply = _randomCheckedFolderJson(random);
      final NodeBackedDeviceRepository repository = _FolderNode(reply: reply)
          .buildRepository();

      final CheckedFolder checked = await repository.checkLocalFolder('/a');
      final CheckedFolder created = await repository.createLocalFolder(
        parent: '/a',
        name: 'b',
      );

      _expectFolderOfReply(checked, reply);
      _expectFolderOfReply(created, reply);
    }
  });

  test(
    'test_map_checked_folder_property_leaves_the_device_list_alone',
    () async {
      final Random random = seededRandom(76906);
      for (int i = 0; i < propertyIterations; i += 1) {
        final _FolderNode folderNode = _FolderNode(
          reply: _randomCheckedFolderJson(random),
        );
        final NodeBackedDeviceRepository repository = folderNode
            .buildRepository();
        int heard = 0;
        repository.addListener(() => heard += 1);

        await repository.checkLocalFolder(randomText(random));
        await repository.createLocalFolder(parent: '/a', name: 'b');

        expect(heard, 0);
        expect(repository.listDevices(), isEmpty);
        expect(folderNode.commands.length, 2);
      }
    },
  );
}
