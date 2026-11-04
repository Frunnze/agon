import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../bridge/support/scripted_node_transport.dart';
import '../../support/random_inputs.dart';
import '../../support/sample_folder_paths.dart';
import 'support/node_backed_harness.dart';

const List<String> _branches = <String>['main', 'master', 'dev-2'];
const List<String> _problems = <String>[
  'the folder /x is not a git repository',
  'the folder /y does not exist or this app cannot open it',
];

void main() {
  test('test_check_local_folder_property_asks_the_node_once', () async {
    final Random random = seededRandom(9201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String path = buildTemporaryFolderPath(randomWordPhrase(random));
      final String address = 'local:3f2a9c:$path';
      final String branch = pickOne(random, _branches);
      final bool hasStartedGit = random.nextBool();
      final List<Object?> sentCommands = <Object?>[];
      final NodeBackedDeviceRepository repository = NodeBackedDeviceRepository(
        channel: buildSimulatedChannel((String inputJson) {
          sentCommands.add(jsonDecode(inputJson));
          return encodeSuccessReply(<String, Object?>{
            'address': address,
            'default_branch': branch,
            'has_started_git': hasStartedGit,
          });
        }),
      );

      final CheckedFolder checked = await repository.checkLocalFolder(path);

      expect(sentCommands, <Object?>[
        <String, Object?>{'command': 'check_local_folder', 'path': path},
      ]);
      expect(checked.repository.address, address);
      expect(checked.repository.defaultBranch, branch);
      expect(checked.hasStartedGit, hasStartedGit);
    }
  });

  test(
    'test_check_local_folder_property_passes_on_the_node_problem',
    () async {
      for (final String problem in _problems) {
        final NodeBackedDeviceRepository repository =
            NodeBackedDeviceRepository(
              channel: buildSimulatedChannel(
                (String inputJson) => encodeErrorReply(problem),
              ),
            );

        await expectLater(
          repository.checkLocalFolder('/x'),
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
}
