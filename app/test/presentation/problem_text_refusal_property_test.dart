import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/bridge/node/node_command_failure.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/presentation/problem_text.dart';

import '../bridge/support/scripted_node_transport.dart';
import '../support/random_app_server_refusals.dart';
import '../support/random_inputs.dart';

const RepositoryBranchLocation _location = RepositoryBranchLocation(
  projectId: ProjectId('project-1'),
  repositoryAddress: 'github.com/acme/app',
  runnerId: DeviceId('runner-1'),
  branch: 'main',
);

String? _describeNodeMessage(String nodeMessage) {
  return describeProblemForPeople(
    translateNodeFailure(NodeCommandFailure(nodeMessage)),
  );
}

Future<Object> _catchFileReadProblem(String nodeMessage) async {
  final NodeBackedFileRepository repository = NodeBackedFileRepository(
    channel: NodeCommandChannel(
      transport: ScriptedNodeTransport(
        answer: (String _) => encodeErrorReply(nodeMessage),
      ),
    ),
  );
  try {
    await repository.readFile(location: _location, path: 'README.md');
  } on Object catch (problem) {
    return problem;
  }
  fail('the refused read succeeded');
}

void main() {
  test(
    'test_describe_problem_for_people_property_refusals_show_the_reason',
    () {
      final Random random = seededRandom(76201);
      for (int i = 0; i < propertyIterations; i += 1) {
        final RandomRefusal refusal = randomRefusal(random);

        final String? shown = _describeNodeMessage(refusal.nodeMessage);

        expect(shown, refusal.reason);
        expect(shown, isNot(startsWith(appServerRefusalPrefix)));
      }
    },
  );

  test('test_describe_problem_for_people_property_one_prefix_is_removed', () {
    final Random random = seededRandom(76202);
    for (int i = 0; i < propertyIterations; i += 1) {
      final RandomRefusal inner = randomRefusal(random);
      final RandomRefusal outer = randomRefusalWithReason(
        random,
        inner.nodeMessage,
      );

      final String? shown = _describeNodeMessage(outer.nodeMessage);

      expect(shown, inner.nodeMessage);
      expect(_describeNodeMessage(shown!), inner.reason);
    }
  });

  test(
    'test_describe_problem_for_people_property_refused_reads_are_plain',
    () async {
      final Random random = seededRandom(76203);
      for (int i = 0; i < propertyIterations; i += 1) {
        final RandomRefusal refusal = randomRefusal(random);

        final Object problem = await _catchFileReadProblem(
          refusal.nodeMessage,
        );

        expect(problem, isA<StateError>());
        expect(describeProblemForPeople(problem), refusal.reason);
      }
    },
  );
}
