import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../bridge/support/scripted_node_transport.dart';
import '../../support/random_inputs.dart';
import 'support/node_backed_harness.dart';

const List<String> _folderNames = <String>['billing', 'app', 'site-2'];

void main() {
  test('test_create_local_folder_property_asks_the_node_once', () async {
    final Random random = seededRandom(9211);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String parent =
          '${Directory.systemTemp.path}/${randomWordPhrase(random)}';
      final String name = pickOne(random, _folderNames);
      final String address = 'local:3f2a9c:$parent/$name';
      final List<Object?> sentCommands = <Object?>[];
      final NodeBackedDeviceRepository repository = NodeBackedDeviceRepository(
        channel: buildSimulatedChannel((String inputJson) {
          sentCommands.add(jsonDecode(inputJson));
          return encodeSuccessReply(<String, Object?>{
            'address': address,
            'default_branch': 'main',
            'has_started_git': true,
          });
        }),
      );

      final CheckedFolder created = await repository.createLocalFolder(
        parent: parent,
        name: name,
      );

      expect(sentCommands, <Object?>[
        <String, Object?>{
          'command': 'create_local_folder',
          'parent': parent,
          'name': name,
        },
      ]);
      expect(created.repository.address, address);
      expect(created.repository.defaultBranch, 'main');
      expect(created.hasStartedGit, isTrue);
    }
  });

  test('a refused folder passes on the node problem', () async {
    final String parent = Directory.systemTemp.path;
    final String existingProblem =
        'the folder $parent/app already exists, so choose another name or '
        'place';
    final NodeBackedDeviceRepository repository = NodeBackedDeviceRepository(
      channel: buildSimulatedChannel(
        (String inputJson) => encodeErrorReply(existingProblem),
      ),
    );

    await expectLater(
      repository.createLocalFolder(parent: parent, name: 'app'),
      throwsA(
        isA<StateError>().having(
          (StateError error) => error.message,
          'message',
          existingProblem,
        ),
      ),
    );
  });
}
