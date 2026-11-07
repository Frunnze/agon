import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/run_chat_values.dart'
    as node;
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../bridge/support/random_moments.dart';
import '../../bridge/support/random_typed_values.dart';
import '../../support/random_inputs.dart';
import 'support/domain_model_properties.dart';

const int _largestSafeInteger = 9007199254740991;

void main() {
  testModelConstructorProperties(
    ModelConstructor<LoopRounds>(
      testNamePrefix: 'test_loop_rounds_constructor_property',
      seed: 691801,
      randomFieldValues: (Random random) => <Object?>[
        randomHostileText(random),
        randomHostileText(random),
        pickOne(random, <int>[0, 1, _largestSafeInteger, random.nextInt(50)]),
      ],
      construct: (ModelFieldValues fieldValues) => LoopRounds(
        from: fieldValues[0]! as String,
        to: fieldValues[1]! as String,
        rounds: fieldValues[2]! as int,
      ),
      readFieldValues: (LoopRounds loopRounds) => <Object?>[
        loopRounds.from,
        loopRounds.to,
        loopRounds.rounds,
      ],
    ),
  );

  testModelConstructorProperties(
    ModelConstructor<RunNote>(
      testNamePrefix: 'test_run_note_constructor_property',
      seed: 691811,
      randomFieldValues: (Random random) => <Object?>[
        randomPreciseMoment(random),
        randomHostileText(random),
      ],
      construct: (ModelFieldValues fieldValues) => RunNote(
        at: fieldValues[0]! as DateTime,
        text: fieldValues[1]! as String,
      ),
      readFieldValues: (RunNote note) => <Object?>[note.at, note.text],
    ),
  );

  testModelConstructorProperties(
    ModelConstructor<LogLine>(
      testNamePrefix: 'test_log_line_constructor_property',
      seed: 691821,
      randomFieldValues: (Random random) => <Object?>[
        randomPreciseMoment(random),
        randomHostileText(random),
        randomHostileText(random),
        random.nextBool(),
      ],
      construct: (ModelFieldValues fieldValues) => LogLine(
        at: fieldValues[0]! as DateTime,
        stepName: fieldValues[1]! as String,
        text: fieldValues[2]! as String,
        isError: fieldValues[3]! as bool,
      ),
      readFieldValues: (LogLine line) => <Object?>[
        line.at,
        line.stepName,
        line.text,
        line.isError,
      ],
    ),
  );

  testModelConstructorProperties(
    ModelConstructor<ChatMessage>(
      testNamePrefix: 'test_chat_message_constructor_property',
      seed: 691831,
      randomFieldValues: (Random random) => <Object?>[
        randomPreciseMoment(random),
        pickOne(random, ChatAuthor.values),
        randomHostileText(random),
        random.nextBool(),
        random.nextBool(),
      ],
      construct: (ModelFieldValues fieldValues) => ChatMessage(
        at: fieldValues[0]! as DateTime,
        author: fieldValues[1]! as ChatAuthor,
        text: fieldValues[2]! as String,
        isError: fieldValues[3]! as bool,
        waitingToSend: fieldValues[4]! as bool,
      ),
      readFieldValues: (ChatMessage message) => <Object?>[
        message.at,
        message.author,
        message.text,
        message.isError,
        message.waitingToSend,
      ],
    ),
  );

  testModelConstructorProperties(
    ModelConstructor<RunFailure>(
      testNamePrefix: 'test_run_failure_constructor_property',
      seed: 691841,
      randomFieldValues: (Random random) => <Object?>[
        randomHostileText(random),
        if (random.nextBool()) null else randomDeviceId(random),
        randomHostileText(random),
        random.nextBool(),
      ],
      construct: (ModelFieldValues fieldValues) => RunFailure(
        stepName: fieldValues[0]! as String,
        runner: fieldValues[1] as DeviceId?,
        reason: fieldValues[2]! as String,
        retryRunsOnSameRunner: fieldValues[3]! as bool,
      ),
      readFieldValues: (RunFailure failure) => <Object?>[
        failure.stepName,
        failure.runner,
        failure.reason,
        failure.retryRunsOnSameRunner,
      ],
    ),
  );

  testNodeEnumMappingProperties(
    const NodeEnumMapping<ChatAuthor, node.ChatAuthor>(
      testNamePrefix: 'test_chat_author_values_property',
      choices: ChatAuthor.values,
      nodeChoices: node.ChatAuthor.values,
      mapFromNode: mapChatAuthorFromNode,
    ),
  );
}
