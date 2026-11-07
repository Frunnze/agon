import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/data/rules/pairing_invitation.dart';
import 'package:agent_orchestration/data/rules/setup_input_rules.dart';

import '../../support/random_inputs.dart';

const String _brokenServerProblem =
    'This pairing code has a broken server address';
const List<String> _brokenServerAddresses = <String>[
  '',
  ' ',
  'relay.acme.dev',
  'ftp://relay.acme.dev',
  'https://',
  'http:relay',
  'https://:7000',
];
const List<String> _usableSchemes = <String>['https', 'http', 'peer'];
const String _hostLetters = 'abcdefghijklmnopqrstuvwxyz0123456789';

String _randomHost(Random random) {
  final int length = 1 + random.nextInt(12);
  final StringBuffer host = StringBuffer();
  for (int i = 0; i < length; i += 1) {
    host.write(_hostLetters[random.nextInt(_hostLetters.length)]);
  }
  return host.toString();
}

String _randomUsableAddress(Random random) {
  final String scheme = pickOne(random, _usableSchemes);
  final String port = random.nextBool() ? '' : ':${random.nextInt(65535)}';
  final String path = random.nextBool() ? '' : '/${_randomHost(random)}';
  return '$scheme://${_randomHost(random)}.dev$port$path';
}

String _randomBrokenAddress(Random random) {
  if (random.nextBool()) {
    return pickOne(random, _brokenServerAddresses);
  }
  return randomText(random);
}

String _encodeWithServer(Random random, String serverAddress) {
  return encodePairingInvitation(
    PairingInvitation(code: randomText(random), serverAddress: serverAddress),
  );
}

void main() {
  test('test_decode_pairing_invitation_property_broken_servers_refused', () {
    final Random random = seededRandom(52901);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String serverAddress = _randomBrokenAddress(random);
      if (describeServerAddressProblem(serverAddress) == null) {
        continue;
      }
      final String text = _encodeWithServer(random, serverAddress);

      expect(
        () => decodePairingInvitation(text),
        throwsA(
          isA<FormatException>().having(
            (FormatException problem) => problem.message,
            'message',
            _brokenServerProblem,
          ),
        ),
      );
    }
  });

  test(
    'test_decode_pairing_invitation_property_usable_servers_round_trip',
    () {
      final Random random = seededRandom(52902);

      for (int i = 0; i < propertyIterations; i += 1) {
        final PairingInvitation invitation = PairingInvitation(
          code: randomText(random),
          serverAddress: _randomUsableAddress(random),
        );

        final PairingInvitation decoded = decodePairingInvitation(
          encodePairingInvitation(invitation),
        );

        expect(describeServerAddressProblem(invitation.serverAddress), isNull);
        expect(decoded.code, invitation.code);
        expect(decoded.serverAddress, invitation.serverAddress);
      }
    },
  );

  test('test_decode_pairing_invitation_property_decoded_servers_usable', () {
    final Random random = seededRandom(52903);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String serverAddress = random.nextBool()
          ? _randomUsableAddress(random)
          : _randomBrokenAddress(random);
      final String text = _encodeWithServer(random, serverAddress);

      try {
        final PairingInvitation decoded = decodePairingInvitation(text);
        expect(describeServerAddressProblem(decoded.serverAddress), isNull);
      } on FormatException catch (problem) {
        expect(problem.message, _brokenServerProblem);
      }
    }
  });
}
