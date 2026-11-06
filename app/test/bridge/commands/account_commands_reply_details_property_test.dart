import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/account_values.dart';
import 'package:agent_orchestration/bridge/codecs/device_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/server_group_values.dart';
import 'package:agent_orchestration/bridge/commands/account_commands.dart';

import '../../support/random_inputs.dart';
import '../support/moment_offset_texts.dart';
import '../support/random_account_json.dart';
import '../support/random_moments.dart';

const int _nanosecondsPerMicrosecond = 1000;
const int _nanosecondsPerSecond = 1000000000;
const int _nanosecondDigitCount = 9;
const String _wholeSecondSuffix = '.000Z';

String _writeNanosecondMomentText(DateTime wholeSecond, int nanoseconds) {
  final String wholeSecondText = wholeSecond.toIso8601String();
  final int prefixLength = wholeSecondText.length - _wholeSecondSuffix.length;
  final String withoutFraction = wholeSecondText.substring(0, prefixLength);
  final String fraction = nanoseconds.toString().padLeft(
    _nanosecondDigitCount,
    '0',
  );
  return '$withoutFraction.${fraction}Z';
}

JsonObject _serverHealthJsonCheckedAt(Random random, String checkedAtText) {
  return <String, Object?>{
    ...randomServerHealthJson(random),
    'checked_at': checkedAtText,
  };
}

void main() {
  test('test_status_command_decode_reply_property_agrees_with_parts', () {
    final Random random = seededRandom(54193);
    const StatusCommand command = StatusCommand();

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject accountJson = randomAccountSummaryJson(random);
      final JsonObject appServersJson = randomAppServersJson(random);
      final JsonObject replyJson = <String, Object?>{
        ...randomStatusViewJson(random),
        'account': accountJson,
        'app_servers': appServersJson,
      };

      final StatusView status = command.decodeReply(replyJson);
      final AccountSummary account = const CreateHostedAccountCommand(
        workspaceName: '',
        deviceName: '',
        role: DeviceRole.client,
      ).decodeReply(accountJson);
      final AppServersView appServers = const StartServerBackupCommand()
          .decodeReply(appServersJson);

      expect(status.account?.toJson(), equals(account.toJson()));
      expect(status.appServers.toJson(), equals(appServers.toJson()));
    }
  });

  test(
    'test_retry_server_command_decode_reply_property_any_offset_moment',
    () {
      final Random random = seededRandom(54190);
      const RetryServerCommand command = RetryServerCommand();

      for (int i = 0; i < propertyIterations; i += 1) {
        final DateTime checkedAt = randomPreciseUtcMoment(random);
        final String checkedAtText = writeMomentWithRandomOffset(
          random,
          checkedAt,
        );
        final JsonObject replyJson = _serverHealthJsonCheckedAt(
          random,
          checkedAtText,
        );

        final ServerHealthView health = command.decodeReply(replyJson);

        expect(health.checkedAt.isUtc, isTrue, reason: checkedAtText);
        expect(health.checkedAt.isAtSameMomentAs(checkedAt), isTrue);
      }
    },
  );

  test(
    'test_retry_server_command_decode_reply_property_needs_moment_zone',
    () {
      final Random random = seededRandom(54191);
      const RetryServerCommand command = RetryServerCommand();

      for (int i = 0; i < propertyIterations; i += 1) {
        final String checkedAtText = textWithoutZone(
          randomPreciseUtcMoment(random),
        );
        final JsonObject replyJson = _serverHealthJsonCheckedAt(
          random,
          checkedAtText,
        );

        expect(
          () => command.decodeReply(replyJson),
          throwsFormatException,
          reason: checkedAtText,
        );
      }
    },
  );

  test(
    'test_retry_server_command_decode_reply_property_reads_nanoseconds',
    () {
      final Random random = seededRandom(54192);
      const RetryServerCommand command = RetryServerCommand();

      for (int i = 0; i < propertyIterations; i += 1) {
        final DateTime wholeSecond = randomUtcMoment(random);
        final int nanoseconds = random.nextInt(_nanosecondsPerSecond);
        final String checkedAtText = _writeNanosecondMomentText(
          wholeSecond,
          nanoseconds,
        );
        final JsonObject replyJson = _serverHealthJsonCheckedAt(
          random,
          checkedAtText,
        );

        final ServerHealthView health = command.decodeReply(replyJson);
        final Duration sinceWholeSecond = health.checkedAt.difference(
          wholeSecond,
        );
        final int decodedNanoseconds =
            sinceWholeSecond.inMicroseconds * _nanosecondsPerMicrosecond;
        final int nanosecondsLost = (decodedNanoseconds - nanoseconds).abs();

        expect(health.checkedAt.isUtc, isTrue);
        expect(nanosecondsLost, lessThan(_nanosecondsPerMicrosecond));
      }
    },
  );
}
