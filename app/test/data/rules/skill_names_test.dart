import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_library.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/rules/skill_names.dart';

import '../../support/random_inputs.dart';

void main() {
  test('test_require_free_skill_name_property_refuses_only_taken_names', () {
    final Random random = seededRandom(7201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Skill> otherSkills = <Skill>[
        for (final Skill skill in gallerySkills)
          if (random.nextBool()) skill,
      ];
      final String name = random.nextBool()
          ? pickOne(random, gallerySkills).name
          : 'free-${random.nextInt(100000)}';
      final bool isTaken = otherSkills.any(
        (Skill skill) => skill.name == name,
      );

      if (isTaken) {
        expect(
          () => requireFreeSkillName(name: name, otherSkills: otherSkills),
          throwsA(
            isA<StateError>().having(
              (StateError error) => error.message,
              'message',
              'A skill named $name already exists',
            ),
          ),
        );
      } else {
        requireFreeSkillName(name: name, otherSkills: otherSkills);
      }
    }
  });
}
