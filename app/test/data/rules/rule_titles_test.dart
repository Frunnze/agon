import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/rules/rule_titles.dart';

import '../../support/random_inputs.dart';

void main() {
  test('test_require_rule_title_property_refuses_only_blank_titles', () {
    final Random random = seededRandom(7202);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String title = pickOne(random, <String>[
        '',
        ' ' * random.nextInt(4),
        '\t\n',
        randomText(random),
      ]);

      if (title.trim().isEmpty) {
        expect(() => requireRuleTitle(title), throwsArgumentError);
      } else {
        requireRuleTitle(title);
      }
    }
  });
}
