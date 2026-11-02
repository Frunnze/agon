import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/data/rules/pairing_invitation.dart';

import '../../support/random_inputs.dart';

PairingInvitation randomInvitation(Random random) {
  return PairingInvitation(
    code: randomText(random),
    serverAddress: 'https://${randomWordPhrase(random)}${randomText(random)}',
  );
}

String mutateText(Random random, String text) {
  if (text.isEmpty) {
    return randomText(random);
  }
  final int position = random.nextInt(text.length);
  final String replacement = randomText(random);

  return text.replaceRange(position, position + 1, replacement);
}

void main() {
  test('test_encode_pairing_invitation_property_round_trips', () {
    final Random random = seededRandom(9711);

    for (int i = 0; i < propertyIterations; i += 1) {
      final PairingInvitation invitation = randomInvitation(random);
      final PairingInvitation decoded = decodePairingInvitation(
        encodePairingInvitation(invitation),
      );

      expect(decoded.code, invitation.code);
      expect(decoded.serverAddress, invitation.serverAddress);
    }
  });

  test('test_encode_pairing_invitation_property_names_scheme_and_version', () {
    final Random random = seededRandom(9712);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String text = encodePairingInvitation(randomInvitation(random));

      expect(text, startsWith('agent-orchestration:pair?v=1&'));
      expect(text.contains(' '), isFalse);
    }
    expect(
      encodePairingInvitation(
        const PairingInvitation(
          code: '4F7-K2Q',
          serverAddress: 'https://relay.acme.dev',
        ),
      ),
      'agent-orchestration:pair?v=1&code=4F7-K2Q'
      '&server=https%3A%2F%2Frelay.acme.dev',
    );
  });

  test('test_decode_pairing_invitation_property_other_versions_fail', () {
    final Random random = seededRandom(9713);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String version = '${2 + random.nextInt(50)}';
      final String text = encodePairingInvitation(randomInvitation(random))
          .replaceFirst('v=1', 'v=$version');

      expect(
        () => decodePairingInvitation(text),
        throwsA(isA<FormatException>()),
      );
    }
  });

  test('test_decode_pairing_invitation_fuzz_property_only_format_errors', () {
    final Random random = seededRandom(9714);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String valid = encodePairingInvitation(randomInvitation(random));
      final String text = random.nextBool()
          ? randomText(random)
          : mutateText(random, valid);

      try {
        final PairingInvitation decoded = decodePairingInvitation(text);
        expect(decoded.code, isA<String>());
      } on FormatException {
        continue;
      }
    }
  });

  test('decode pairing invitation rejects other links and missing parts', () {
    for (final String text in <String>[
      'https://relay.acme.dev/pair?v=1&code=4F7-K2Q&server=x',
      'agent-orchestration:join?v=1&code=4F7-K2Q&server=x',
      'agent-orchestration:pair?v=1&server=https%3A%2F%2Frelay.acme.dev',
      'agent-orchestration:pair?v=1&code=4F7-K2Q',
      'agent-orchestration:pair?code=4F7-K2Q&server=x',
      '',
    ]) {
      expect(
        () => decodePairingInvitation(text),
        throwsA(isA<FormatException>()),
        reason: text,
      );
    }
  });
}
