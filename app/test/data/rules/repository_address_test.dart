import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/rules/repository_address.dart';

import '../../support/random_inputs.dart';

const List<String> _owners = <String>['acme', 'air', 'big-co', 'a_b', 'x.y'];
const List<String> _names = <String>['app', 'api', 'billing', 'docs-site'];
const List<String> _hosts = <String>['github.com', 'gitlab.example.org'];

void main() {
  test('test_parse_repository_address_property_every_form_agrees', () {
    final Random random = seededRandom(8301);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String host = pickOne(random, _hosts);
      final String owner = pickOne(random, _owners);
      final String name = pickOne(random, _names);
      final String canonical = '$host/$owner/$name';
      final List<String> forms = <String>[
        canonical,
        'https://$canonical',
        'https://$canonical.git',
        'git@$host:$owner/$name.git',
        '  $canonical/  ',
      ];

      for (final String form in forms) {
        expect(parseRepositoryAddress(form), canonical, reason: form);
      }
    }
  });

  test('test_parse_repository_address_fuzz_property_never_throws', () {
    final Random random = seededRandom(8302);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String text = random.nextBool()
          ? randomText(random)
          : randomWordPhrase(random).replaceAll(' ', '/');
      final String? parsed = parseRepositoryAddress(text);

      if (parsed != null) {
        expect(parsed.split('/').length, 3);
        expect(parseRepositoryAddress(parsed), parsed);
      }
    }
  });

  test('parse repository address rejects what is not an address', () {
    expect(parseRepositoryAddress(''), isNull);
    expect(parseRepositoryAddress('acme/app'), isNull);
    expect(parseRepositoryAddress('http://github.com/acme/app'), isNull);
    expect(parseRepositoryAddress('git@github.com/acme/app'), isNull);
    expect(parseRepositoryAddress('github.com/acme/../app'), isNull);
    expect(parseRepositoryAddress('github/acme/app'), isNull);
    expect(parseRepositoryAddress('github.com/acme/app/extra'), isNull);
    expect(parseRepositoryAddress('github.com/ac me/app'), isNull);
  });
}
