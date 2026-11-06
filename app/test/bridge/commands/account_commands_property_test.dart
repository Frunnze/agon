import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/device_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/commands/account_commands.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';

import '../../support/random_inputs.dart';
import '../support/account_command_shapes.dart';
import '../support/arbitrary_json.dart';
import '../support/command_shape.dart';
import '../support/hostile_texts.dart';

const int _largestWholeNumber = 0x7FFFFFFFFFFFFFFF;
const int _largestJsonSafeWholeNumber = 9007199254740991;

const List<int> _boundaryAfterSequences = <int>[
  0,
  1,
  (1 << 31) - 1,
  1 << 31,
  (1 << 32) - 1,
  1 << 32,
  _largestJsonSafeWholeNumber,
  _largestJsonSafeWholeNumber + 2,
  _largestWholeNumber,
];

const List<Object?> _falsyLookingReplies = <Object?>[
  false,
  0,
  0.0,
  -0.0,
  '',
  ' ',
  'null',
  <Object?>[],
  <String, Object?>{},
  <Object?>[null],
  <String, Object?>{'ok': null},
];

CreateAccountCommand _randomCreateAccountCommand(Random random) {
  return CreateAccountCommand(
    serverAddress: randomHostileText(random),
    setupCode: randomHostileText(random),
    deviceName: randomHostileText(random),
    role: pickOne(random, DeviceRole.values),
    workspaceName: randomHostileText(random),
  );
}

CreateHostedAccountCommand _randomCreateHostedAccountCommand(Random random) {
  return CreateHostedAccountCommand(
    workspaceName: randomHostileText(random),
    deviceName: randomHostileText(random),
    role: pickOne(random, DeviceRole.values),
  );
}

PollEventsCommand _randomPollEventsCommand(Random random) {
  if (random.nextBool()) {
    return PollEventsCommand(after: pickOne(random, _boundaryAfterSequences));
  }
  return PollEventsCommand(after: random.nextInt(1 << 32));
}

JsonObject _rereadThroughJsonText(NodeCommand<Object?> command) {
  final String commandText = jsonEncode(encodeNodeCommand(command));
  return decodeObject(jsonDecode(commandText));
}

void _expectSameCommandAfterJsonText(NodeCommand<Object?> command) {
  final JsonObject reread = _rereadThroughJsonText(command);
  final JsonObject rereadArguments = Map<String, Object?>.of(reread);
  rereadArguments.remove(commandNameField);

  expect(reread[commandNameField], command.name);
  expect(rereadArguments, equals(command.arguments));
}

void _expectIndependentReads(NodeCommand<Object?> command) {
  final JsonObject firstRead = command.arguments;
  final JsonObject firstReadCopy = Map<String, Object?>.of(firstRead);

  firstRead.clear();

  expect(command.arguments, equals(firstReadCopy));
}

void main() {
  test('test_create_account_command_arguments_property_sends_node_fields', () {
    final Random random = seededRandom(54001);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CreateAccountCommand command = _randomCreateAccountCommand(random);
      final JsonObject expectedArguments = <String, Object?>{
        'server_address': command.serverAddress,
        'setup_code': command.setupCode,
        'device_name': command.deviceName,
        'role': command.role.wireName,
        'workspace_name': command.workspaceName,
      };

      expect(command.arguments, equals(expectedArguments));
    }
  });

  test('test_create_account_command_arguments_property_survive_json_text', () {
    final Random random = seededRandom(54002);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CreateAccountCommand command = _randomCreateAccountCommand(random);
      final JsonObject reread = _rereadThroughJsonText(command);

      _expectSameCommandAfterJsonText(command);
      expect(DeviceRole.decode(reread['role']), command.role);
    }
  });

  test(
    'test_create_account_command_arguments_property_reads_are_independent',
    () {
      final Random random = seededRandom(54003);

      for (int i = 0; i < propertyIterations; i += 1) {
        _expectIndependentReads(_randomCreateAccountCommand(random));
      }
    },
  );

  test(
    'test_create_hosted_account_command_arguments_property_sends_node_fields',
    () {
      final Random random = seededRandom(54004);

      for (int i = 0; i < propertyIterations; i += 1) {
        final CreateHostedAccountCommand command =
            _randomCreateHostedAccountCommand(random);
        final JsonObject expectedArguments = <String, Object?>{
          'workspace_name': command.workspaceName,
          'device_name': command.deviceName,
          'role': command.role.wireName,
        };

        expect(command.arguments, equals(expectedArguments));
      }
    },
  );

  test(
    'test_create_hosted_account_command_arguments_property_survive_json_text',
    () {
      final Random random = seededRandom(54005);

      for (int i = 0; i < propertyIterations; i += 1) {
        final CreateHostedAccountCommand command =
            _randomCreateHostedAccountCommand(random);
        final JsonObject reread = _rereadThroughJsonText(command);

        _expectSameCommandAfterJsonText(command);
        expect(DeviceRole.decode(reread['role']), command.role);
      }
    },
  );

  test(
    'test_create_hosted_account_command_arguments_property_independent_reads',
    () {
      final Random random = seededRandom(54006);

      for (int i = 0; i < propertyIterations; i += 1) {
        _expectIndependentReads(_randomCreateHostedAccountCommand(random));
      }
    },
  );

  test('test_poll_events_command_arguments_property_sends_after_as_is', () {
    final Random random = seededRandom(54007);

    for (int i = 0; i < propertyIterations; i += 1) {
      final PollEventsCommand command = _randomPollEventsCommand(random);
      final JsonObject expectedArguments = <String, Object?>{
        'after': command.after,
      };

      expect(command.arguments, equals(expectedArguments));
    }
  });

  test(
    'test_poll_events_command_arguments_property_after_stays_whole_in_text',
    () {
      final Random random = seededRandom(54008);

      for (int i = 0; i < propertyIterations; i += 1) {
        final PollEventsCommand command = _randomPollEventsCommand(random);
        final JsonObject reread = _rereadThroughJsonText(command);

        _expectSameCommandAfterJsonText(command);
        expect(reread['after'], isA<int>());
        expect(reread['after'], command.after);
      }
    },
  );

  test(
    'test_poll_events_command_arguments_property_reads_are_independent',
    () {
      final Random random = seededRandom(54009);

      for (int i = 0; i < propertyIterations; i += 1) {
        _expectIndependentReads(_randomPollEventsCommand(random));
      }
    },
  );

  test(
    'test_forget_this_device_command_decode_reply_property_only_null_passes',
    () {
      final Random random = seededRandom(54010);
      const ForgetThisDeviceCommand command = ForgetThisDeviceCommand();

      for (int i = 0; i < propertyIterations; i += 1) {
        final Object? replyJson = randomArbitraryJson(random);
        final Object? replyFromText = jsonDecode(jsonEncode(replyJson));

        if (replyJson == null) {
          expect(() => command.decodeReply(replyFromText), returnsNormally);
        } else {
          expect(
            () => command.decodeReply(replyFromText),
            throwsFormatException,
            reason: '$replyJson',
          );
        }
      }
    },
  );

  test(
    'test_forget_this_device_command_decode_reply_property_rejects_falsy',
    () {
      final Random random = seededRandom(54011);
      const ForgetThisDeviceCommand command = ForgetThisDeviceCommand();

      for (int i = 0; i < propertyIterations; i += 1) {
        final Object? replyJson = random.nextBool()
            ? pickOne(random, _falsyLookingReplies)
            : randomHostileText(random);

        expect(
          () => command.decodeReply(replyJson),
          throwsFormatException,
          reason: '$replyJson',
        );
      }
    },
  );

  test(
    'test_forget_this_device_command_decode_reply_property_rejects_views',
    () {
      final Random random = seededRandom(54012);
      const ForgetThisDeviceCommand command = ForgetThisDeviceCommand();

      for (int i = 0; i < propertyIterations; i += 1) {
        final CommandShape shape = pickOne(random, accountCommandShapes);
        final Object? replyJson = shape.buildReplyJson(random);
        if (replyJson == null) {
          continue;
        }

        expect(
          () => command.decodeReply(replyJson),
          throwsFormatException,
          reason: shape.commandName,
        );
      }
    },
  );
}
