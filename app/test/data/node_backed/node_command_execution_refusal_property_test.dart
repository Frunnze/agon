import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/commands/account_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/bridge/node/node_command_failure.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/app_server_refusal.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../bridge/support/scripted_node_transport.dart';
import '../../support/random_app_server_refusals.dart';
import '../../support/random_inputs.dart';

const List<String> _malformedStatuses = <String>[
  '',
  '4',
  '40',
  '4040',
  ' 404',
  '+40',
  '-40',
  'abc',
  '٤٠٤',
];
const List<String> _blankReasons = <String>['', ' ', '\t', '\n', '  \n '];
const List<String> _missingThings = <String>[
  'the task',
  'the pairing session',
  'the workspace member',
  'project 42',
];

String _randomMalformedRefusal(Random random) {
  final String status = pickOne(random, _malformedStatuses);
  final String reason = randomRefusalReason(random);
  final List<String> malformed = <String>[
    '$appServerRefusalPrefix $status: $reason',
    '$appServerRefusalPrefix ${random.nextInt(900) + 100} $reason',
    renderRefusalMessage(
      status: random.nextInt(900) + 100,
      reason: pickOne(random, _blankReasons),
    ),
    '${randomText(random)}x${renderRefusalMessage(status: 404, reason: 'r')}',
  ];
  return pickOne(random, malformed);
}

void main() {
  test(
    'test_translate_node_failure_property_refusals_keep_status_and_reason',
    () {
      final Random random = seededRandom(76101);
      for (int i = 0; i < propertyIterations; i += 1) {
        final RandomRefusal refusal = randomRefusal(random);

        final Object translated = translateNodeFailure(
          NodeCommandFailure(refusal.nodeMessage),
        );

        expect(translated, isA<AppServerRefusal>());
        final AppServerRefusal structured = translated as AppServerRefusal;
        expect(structured.status, refusal.status);
        expect(structured.message, refusal.reason);
        expect(structured.message, isNot(contains(appServerRefusalPrefix)));
      }
    },
  );

  test(
    'test_translate_node_failure_property_refusals_round_trip_their_text',
    () {
      final Random random = seededRandom(76102);
      for (int i = 0; i < propertyIterations; i += 1) {
        final RandomRefusal refusal = randomRefusal(random);

        final Object translated = translateNodeFailure(
          NodeCommandFailure(refusal.nodeMessage),
        );

        expect(translated.toString(), refusal.nodeMessage);
        final Object again = translateNodeFailure(
          NodeCommandFailure(translated.toString()),
        );
        expect((again as AppServerRefusal).status, refusal.status);
        expect(again.message, refusal.reason);
      }
    },
  );

  test(
    'test_translate_node_failure_property_refused_lookups_are_not_records',
    () {
      final Random random = seededRandom(76103);
      for (int i = 0; i < propertyIterations; i += 1) {
        final String reason =
            '${pickOne(random, _missingThings)} was not found';
        final RandomRefusal refusal = randomRefusalWithReason(random, reason);

        final Object translated = translateNodeFailure(
          NodeCommandFailure(refusal.nodeMessage),
        );

        expect(translated, isNot(isA<RecordNotFound>()));
        expect((translated as AppServerRefusal).message, reason);
        expect(translated.status, refusal.status);
      }
    },
  );

  test(
    'test_translate_node_failure_property_malformed_refusals_stay_whole',
    () {
      final Random random = seededRandom(76104);
      for (int i = 0; i < propertyIterations; i += 1) {
        final String message = _randomMalformedRefusal(random);

        final Object translated = translateNodeFailure(
          NodeCommandFailure(message),
        );

        expect(translated, isNot(isA<AppServerRefusal>()));
        expect(translated, isA<StateError>());
        expect((translated as StateError).message, message);
      }
    },
  );

  test(
    'test_execute_node_command_property_refusals_arrive_structured',
    () async {
      final Random random = seededRandom(76105);
      for (int i = 0; i < propertyIterations; i += 1) {
        final RandomRefusal refusal = randomRefusal(random);
        final NodeCommandChannel channel = NodeCommandChannel(
          transport: ScriptedNodeTransport(
            answer: (String _) => encodeErrorReply(refusal.nodeMessage),
          ),
        );

        await expectLater(
          executeNodeCommand(channel, const node.RetryServerCommand()),
          throwsA(
            isA<AppServerRefusal>()
                .having(
                  (AppServerRefusal error) => error.status,
                  'status',
                  refusal.status,
                )
                .having(
                  (AppServerRefusal error) => error.message,
                  'reason',
                  refusal.reason,
                ),
          ),
        );
      }
    },
  );
}
