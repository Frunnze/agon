import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/rules/naming.dart';
import 'package:agent_orchestration/data/rules/setup_input_rules.dart';

import '../../support/random_inputs.dart';

const List<String> _sampleAddresses = <String>[
  'https://relay.acme.dev',
  'http://localhost:8080',
  'https://relay.acme.dev/base',
  'relay.acme.dev',
  'ftp://relay.acme.dev',
  'https://',
  '',
  '  ',
  'https//relay',
  'http://[::1]:9000',
  'peer://3f2a9c1d7e5b4a60?relay=https%3A%2F%2Feuc1.example.org%2F',
  'peer://ab',
  'peer://',
];

const List<String> _sampleHostNames = <String>[
  'Frunzes-MacBook-Air.local',
  'mac-mini',
  'DESKTOP-4F7K2Q',
  '',
  '---',
  'café box',
  'a.b.c',
];

String randomAddress(Random random) {
  if (random.nextBool()) {
    return pickOne(random, _sampleAddresses);
  }
  final String scheme = pickOne(random, <String>[
    'https',
    'http',
    'peer',
    'ws',
    '',
  ]);
  return '$scheme://${randomWordPhrase(random)}${randomText(random)}';
}

void main() {
  test(
    'test_describe_server_address_problem_property_known_scheme_and_host',
    () {
      final Random random = seededRandom(9701);

      for (int i = 0; i < propertyIterations; i += 1) {
        final String address = randomAddress(random);
        final Uri? parsed = Uri.tryParse(address.trim());
        final bool isValid =
            parsed != null &&
            <String>['https', 'http', 'peer'].contains(parsed.scheme) &&
            parsed.host.isNotEmpty;

        expect(describeServerAddressProblem(address) == null, isValid);
      }
      expect(describeServerAddressProblem('https://relay.acme.dev'), isNull);
      expect(
        describeServerAddressProblem('relay.acme.dev'),
        'Start the address with https:// or http://',
      );
      expect(
        describeServerAddressProblem(' '),
        'Enter the app server address',
      );
    },
  );

  test('test_describe_pairing_code_problem_property_six_characters', () {
    final Random random = seededRandom(9702);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String code = random.nextBool()
          ? randomText(random)
          : '${randomText(random).padRight(6, 'x').substring(0, 6)} -';
      final int length = code.replaceAll(RegExp(r'[\s-]'), '').length;

      expect(describePairingCodeProblem(code) == null, length == 6);
    }
    expect(describePairingCodeProblem('4f7 k2q'), isNull);
    expect(
      describePairingCodeProblem('4F7-K2'),
      'A pairing code has six characters',
    );
  });

  test(
    'test_describe_join_input_problem_property_checks_a_given_server_only',
    () {
      final Random random = seededRandom(9703);

      for (int i = 0; i < propertyIterations; i += 1) {
        final String code = pickOne(random, <String>[
          '4F7-K2Q',
          '4f7 k2q',
          '4F7-K2',
          randomText(random),
        ]);
        final String? serverAddress = pickOne(random, <String?>[
          'https://relay.acme.dev',
          'relay.acme',
          randomText(random),
          null,
        ]);
        final String? codeProblem = describePairingCodeProblem(code);
        final String? serverProblem = serverAddress == null
            ? null
            : describeServerAddressProblem(serverAddress);

        expect(
          describeJoinInputProblem(serverAddress: serverAddress, code: code),
          codeProblem ?? serverProblem,
        );
      }
      expect(
        describeJoinInputProblem(serverAddress: null, code: '4f7 k2q'),
        isNull,
      );
    },
  );

  test('test_suggest_device_name_property_always_a_valid_name', () {
    final Random random = seededRandom(9704);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String hostName = random.nextBool()
          ? pickOne(random, _sampleHostNames)
          : randomText(random) * (1 + random.nextInt(3));
      final String suggestion = suggestDeviceName(hostName);

      expect(describeNameProblem(suggestion), isNull, reason: suggestion);
      expect(suggestDeviceName(suggestion), suggestion);
    }
    expect(
      suggestDeviceName('Frunzes-MacBook-Air.local'),
      'frunzes-macbook-air',
    );
    expect(suggestDeviceName('---'), 'new-device');
  });

  test('test_describe_server_host_property_drops_only_the_scheme', () {
    final Random random = seededRandom(9705);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String address = randomAddress(random);
      final String host = describeServerHost(address);
      final Uri? parsed = Uri.tryParse(address.trim());

      if (describeServerAddressProblem(address) == null) {
        if (parsed!.scheme == 'peer') {
          expect(host, startsWith('peer link '));
          expect(parsed.host, startsWith(host.substring(10)));
          expect(host.length, lessThanOrEqualTo(18));
        } else {
          expect(host, parsed.authority);
        }
      } else {
        expect(host, address);
      }
    }
    expect(describeServerHost('https://relay.acme.dev'), 'relay.acme.dev');
    expect(describeServerHost('http://localhost:8080'), 'localhost:8080');
    expect(
      describeServerHost('peer://3f2a9c1d7e5b4a60?relay=https%3A%2F%2Fa.b%2F'),
      'peer link 3f2a9c1d',
    );
  });
}
