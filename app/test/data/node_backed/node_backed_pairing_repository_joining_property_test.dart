import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/data/repository/pairing_repository.dart';
import 'package:agent_orchestration/data/rules/naming.dart';
import 'package:agent_orchestration/data/rules/setup_input_rules.dart';

import '../../support/random_inputs.dart';
import '../fakes/support/pairing_inputs.dart';
import 'support/node_backed_pairing_rig.dart';
import 'support/pairing_repository_harness.dart';
import 'support/simulated_node_replies.dart';
import 'support/simulated_pairing_node.dart';

const String _typePrefix = 'test_node_backed_pairing_repository';
const int _iterations = 15;
const int _neverJoins = 1000000;
const int _quietPolls = 5;
const int _largestWaits = 3;
const Map<String, String> _refusalByAnswer = <String, String>{
  'rejected': 'The other device rejected this pairing',
  'expired': 'The pairing code expired before it was approved',
};

String _randomBadCode(Random random) {
  final String candidate = randomText(random);
  final bool isAccepted =
      describeJoinInputProblem(serverAddress: null, code: candidate) == null;
  if (isAccepted) {
    return '$candidate-extra';
  }
  return candidate;
}

Future<PairingOutcome> _join(PairingRepository repository, String name) {
  return repository.joinWithCode(
    serverAddress: null,
    code: simulatedDisplayCode,
    deviceName: name,
    role: DeviceRole.runner,
  );
}

Matcher _isStateErrorSaying(String message) {
  return isA<StateError>().having(
    (StateError error) => error.message,
    'message',
    message,
  );
}

void main() {
  test('${_typePrefix}_join_with_code_property_bad_device_names_refused_'
      'like_the_fake', () async {
    final Random random = seededRandom(78501);

    for (int i = 0; i < _iterations; i += 1) {
      final String name = randomBadName(random);
      final PairingRig rig = buildPairingRig(pollsBeforeJoin: 0);
      final PairingSetup fake = buildPairingSetup(
        session: null,
        request: null,
        now: pairingStart,
      );

      final String nodeRefusal = await describeArgumentRefusal(
        _join(rig.repository, name),
      );
      final String fakeRefusal = await describeArgumentRefusal(
        _join(fake.pairing, name),
      );

      expect(nodeRefusal, fakeRefusal);
      expect(nodeRefusal, describeNameProblem(name));
      expect(rig.node.commandNames, isEmpty);
      rig.dispose();
    }
  });

  test('${_typePrefix}_join_with_code_property_bad_codes_refused_before_'
      'the_node', () async {
    final Random random = seededRandom(78502);

    for (int i = 0; i < _iterations; i += 1) {
      final String code = _randomBadCode(random);
      final PairingRig rig = buildPairingRig(pollsBeforeJoin: 0);

      await expectLater(
        rig.repository.joinWithCode(
          serverAddress: null,
          code: code,
          deviceName: randomDeviceName(random),
          role: pickOne(random, DeviceRole.values),
        ),
        throwsA(
          isA<FormatException>().having(
            (FormatException problem) => problem.message,
            'message',
            describeJoinInputProblem(serverAddress: null, code: code),
          ),
        ),
      );

      expect(rig.node.commandNames, isEmpty);
      rig.dispose();
    }
  });

  test('${_typePrefix}_join_with_code_property_node_refusal_is_'
      'translated', () async {
    final Random random = seededRandom(78503);

    for (int i = 0; i < _iterations; i += 1) {
      final PairingRig rig = buildPairingRig(pollsBeforeJoin: 0);
      rig.node.failingCommands.add(joinWithCodeCommand);

      await expectLater(
        _join(rig.repository, randomDeviceName(random)),
        throwsA(_isStateErrorSaying(simulatedOutageMessage)),
      );

      expect(rig.repository.findWaitingJoin(), isNull);
      expect(rig.node.countCommands(joinStatusCommand), 0);
      rig.dispose();
    }
  });

  test('test_wait_for_join_answer_property_refusals_in_plain_'
      'words', () async {
    final Random random = seededRandom(78504);

    for (int i = 0; i < _iterations; i += 1) {
      final String answer = pickOne(random, _refusalByAnswer.keys.toList());
      final PairingRig rig = buildPairingRig(
        pollsBeforeJoin: 0,
        joinPollsBeforeAnswer: random.nextInt(_largestWaits),
        joinAnswer: answer,
      );

      await expectLater(
        _join(rig.repository, 'joining-phone'),
        throwsA(_isStateErrorSaying(_refusalByAnswer[answer]!)),
      );

      expect(rig.repository.findWaitingJoin(), isNull);
      rig.dispose();
    }
  });

  test('test_wait_for_join_answer_property_a_status_failure_'
      'ends_the_wait', () async {
    final Random random = seededRandom(78505);

    for (int i = 0; i < _iterations; i += 1) {
      final PairingRig rig = buildPairingRig(
        pollsBeforeJoin: 0,
        joinPollsBeforeAnswer: _neverJoins,
      );
      final Future<PairingOutcome> joining = _join(
        rig.repository,
        'joining-phone',
      );
      final int pollsBeforeFailure = 1 + random.nextInt(_largestWaits);
      await waitUntil(
        () => rig.node.countCommands(joinStatusCommand) >= pollsBeforeFailure,
      );
      rig.node.failingCommands.add(joinStatusCommand);

      await expectLater(
        joining,
        throwsA(_isStateErrorSaying(simulatedOutageMessage)),
      );
      final int pollsAtFailure = rig.node.countCommands(joinStatusCommand);
      await waitForPolls(_quietPolls);

      expect(rig.node.countCommands(joinStatusCommand), pollsAtFailure);
      expect(rig.repository.findWaitingJoin(), isNull);
      rig.dispose();
    }
  });

  test('test_wait_for_join_answer_property_approval_names_the_'
      'approver', () async {
    final Random random = seededRandom(78506);

    for (int i = 0; i < _iterations; i += 1) {
      final int waits = random.nextInt(_largestWaits);
      final PairingRig rig = buildPairingRig(
        pollsBeforeJoin: 0,
        joinPollsBeforeAnswer: waits,
      );

      final PairingOutcome outcome = await _join(
        rig.repository,
        'joining-phone',
      );

      expect(outcome.approverName, simulatedApproverName);
      expect(outcome.deviceName, 'joining-phone');
      expect(outcome.workspaceNames, <String>['home']);
      expect(rig.node.countCommands(joinStatusCommand), waits + 1);
      rig.dispose();
    }
  });
}
