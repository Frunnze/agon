import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/rules/local_folder_address.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';

import '../support/random_inputs.dart';

void main() {
  test('test_shorten_identifier_property_keeps_both_ends', () {
    final Random random = seededRandom(51);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String identifier = randomText(random);
      final String shortened = shortenIdentifier(identifier);

      expect(shortened.length <= identifier.length + 1, isTrue);
      if (shortened != identifier) {
        expect(shortened, contains('…'));
        expect(identifier, startsWith(shortened.split('…').first));
        expect(identifier, endsWith(shortened.split('…').last));
      }
    }
    const String session = '7c1e3f5a9b2d4e6f8a1c3e5b7d9fa90f';
    expect(shortenIdentifier(session), '7c1e…a90f');
  });

  test('test_describe_repository_path_property_drops_only_the_host', () {
    final Random random = seededRandom(52);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String owner = randomWordPhrase(random).replaceAll(' ', '');
      final String name = randomWordPhrase(random).replaceAll(' ', '');
      final String address = 'github.com/$owner/$name';

      expect(describeRepositoryPath(address), '$owner/$name');
    }
    expect(describeRepositoryPath('acme/app'), 'acme/app');
  });

  test('test_describe_repository_path_property_names_a_local_folder', () {
    final Random random = seededRandom(53);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String parent = pickOne(random, <String>['/Users/someone', 'C:\\x']);
      final String name = pickOne(random, <String>['billing', 'a b', 'x.y']);
      final String address = renderLocalFolderAddress(
        deviceId: DeviceId('d${random.nextInt(999)}'),
        path: '$parent/$name',
      );

      expect(describeRepositoryPath(address), name);
    }
  });
}
