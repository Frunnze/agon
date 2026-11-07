import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/skill_repository.dart';

import '../../support/random_inputs.dart';
import '../node_backed/support/node_backed_harness.dart';
import '../node_backed/support/simulated_catalog_node.dart';
import 'support/notification_counter.dart';
import 'support/refusals.dart';
import 'support/skill_inputs.dart';

const int _sequenceIterations = 40;
const int _longestSequence = 10;

typedef _Pair = ({
  FakeSkillRepository fake,
  NodeBackedSkillRepository nodeBacked,
});

typedef _SkillChange = Future<Object?> Function(SkillRepository repository);

bool _refusesTheName(Object error) {
  return error is ArgumentError || error is StateError;
}

String _describeWithoutId(Skill skill) {
  final List<String> fields = <String>[
    skill.name,
    skill.summary,
    skill.instructions,
    skill.usage.name,
    skill.source.name,
    skill.improvement.name,
  ];
  return fields.join('|');
}

List<String> _describeAllWithoutIds(List<Skill> skills) {
  return <String>[for (final Skill skill in skills) _describeWithoutId(skill)];
}

Future<_Pair> _buildPair() async {
  final SimulatedCatalogNode simulated = SimulatedCatalogNode(
    hasAccount: true,
  );
  final NodeBackedSkillRepository nodeBacked = NodeBackedSkillRepository(
    channel: simulated.channel,
    workspaceRepository: buildSingleWorkspaceRepository(),
  );
  await nodeBacked.load();
  return (fake: buildSkillRepository(const <Skill>[]), nodeBacked: nodeBacked);
}

String _pickName(Random random, List<Skill> listed, int index) {
  final int roll = random.nextInt(4);
  if (roll == 0) {
    return randomInvalidSkillName(random);
  }
  if (roll == 1 && listed.isNotEmpty) {
    return pickOne(random, listed).name;
  }
  return 'skill-$index';
}

_SkillChange _pickChange(Random random, List<Skill> listed, int index) {
  final String name = _pickName(random, listed, index);
  final SkillDraft draft = randomSkillDraftNamed(random, name);
  if (listed.isEmpty || random.nextBool()) {
    return (SkillRepository repository) => repository.createSkill(draft);
  }
  final int position = random.nextInt(listed.length);
  if (random.nextBool()) {
    return (SkillRepository repository) =>
        repository.deleteSkill(repository.listSkills()[position].id);
  }
  return (SkillRepository repository) =>
      repository.updateSkill(repository.listSkills()[position].id, draft);
}

void main() {
  test(
    'test_create_skill_property_new_skills_are_created_and_fresh',
    () async {
      final Random random = seededRandom(66501);

      for (int i = 0; i < propertyIterations; i += 1) {
        final FakeSkillRepository repository = buildSkillRepository(
          randomSeededSkills(random),
        );
        final SkillDraft draft = randomSkillDraftNamed(random, 'fresh-$i');

        final Skill created = await repository.createSkill(draft);

        expect(created.name, draft.name);
        expect(created.summary, draft.summary);
        expect(created.instructions, draft.instructions);
        expect(created.usage, draft.usage);
        expect(created.improvement, draft.improvement);
        expect(created.source, SkillSource.created);
        expect(created.history, isEmpty);
      }
    },
  );

  test('test_create_skill_property_refuses_badly_formed_names', () async {
    final Random random = seededRandom(66502);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeSkillRepository repository = buildSkillRepository(
        randomSeededSkills(random),
      );
      final List<String> before = describeSkills(repository.listSkills());
      final NotificationCounter counter = NotificationCounter();
      repository.addListener(counter.record);
      final String name = randomInvalidSkillName(random);

      final bool wasRefused = await isRefused(
        () => repository.createSkill(randomSkillDraftNamed(random, name)),
        isRefusal: _refusesTheName,
      );

      expect(wasRefused, isTrue, reason: 'accepted "$name"');
      expect(describeSkills(repository.listSkills()), before);
      expect(counter.count, 0);
    }
  });

  test('test_create_skill_property_accepts_every_well_formed_name', () async {
    final Random random = seededRandom(66503);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeSkillRepository repository = buildSkillRepository(
        randomSeededSkills(random),
      );
      final String name = randomValidSkillName(random);
      if (isSkillNameListed(repository.listSkills(), name)) {
        continue;
      }

      final Skill created = await repository.createSkill(
        randomSkillDraftNamed(random, name),
      );

      expect(created.name, name);
    }
  });

  test('test_create_skill_property_agrees_with_the_node_backed_'
      'repository', () async {
    final Random random = seededRandom(66505);

    for (int i = 0; i < _sequenceIterations; i += 1) {
      final _Pair pair = await _buildPair();
      final int stepCount = 1 + random.nextInt(_longestSequence);

      for (int step = 0; step < stepCount; step += 1) {
        final _SkillChange change = _pickChange(
          random,
          pair.fake.listSkills(),
          step,
        );
        final bool isFakeRefused = await isRefused(
          () => change(pair.fake),
          isRefusal: _refusesTheName,
        );
        final bool isNodeRefused = await isRefused(
          () => change(pair.nodeBacked),
          isRefusal: _refusesTheName,
        );

        expect(isFakeRefused, isNodeRefused);
        expect(
          _describeAllWithoutIds(pair.fake.listSkills()),
          _describeAllWithoutIds(pair.nodeBacked.listSkills()),
        );
      }
      pair.nodeBacked.dispose();
    }
  });
}
