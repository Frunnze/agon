import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../bridge/support/node_wire_names.dart';
import '../../support/random_inputs.dart';
import 'support/node_backed_harness.dart';
import 'support/simulated_catalog_node.dart';

const int _seededSkillCount = 3;

Map<String, Object?> _randomChangeJson(Random random, int index) {
  final String kind = pickOne(random, nodeSkillChangeOrigins);
  final Map<String, Object?> origin = kind == nodePersonEditOrigin
      ? <String, Object?>{'kind': kind}
      : <String, Object?>{'kind': kind, 'run_id': 'run-$index'};
  return <String, Object?>{
    'origin': origin,
    'saved_at': '2026-10-2${index}T09:00:00.000Z',
    'replaced_instructions': 'Version $index of ${randomText(random)}',
  };
}

void _seedHistories(Random random, SimulatedCatalogNode simulated) {
  for (final Map<String, Object?> skill in simulated.skills) {
    final int changeCount = random.nextInt(4);
    skill['history'] = <Object?>[
      for (int i = 0; i < changeCount; i += 1) _randomChangeJson(random, i),
    ];
  }
}

Map<String, Object?> _findStoredSkill(
  SimulatedCatalogNode simulated,
  SkillId skillId,
) {
  return simulated.skills.firstWhere(
    (Map<String, Object?> skill) => skill['id'] == skillId.value,
  );
}

bool _isAgentChangeNewest(List<Object?> history) {
  if (history.isEmpty) {
    return false;
  }
  final Map<String, Object?> latest = history.last! as Map<String, Object?>;
  final Map<String, Object?> origin =
      latest['origin']! as Map<String, Object?>;
  return origin['kind'] != nodePersonEditOrigin;
}

void main() {
  test('test_undo_latest_agent_change_property_node_and_list_agree', () async {
    final Random random = seededRandom(9911);
    final SimulatedCatalogNode simulated = SimulatedCatalogNode(
      hasAccount: true,
    );
    for (int i = 0; i < _seededSkillCount; i += 1) {
      simulated.addSkill(
        workspaceId: harnessWorkspaceId.value,
        name: 'skill-$i',
      );
    }
    final NodeBackedSkillRepository skills = NodeBackedSkillRepository(
      channel: simulated.channel,
      workspaceRepository: buildSingleWorkspaceRepository(),
    );

    for (int i = 0; i < propertyIterations; i += 1) {
      _seedHistories(random, simulated);
      await skills.load();
      final Skill skill = pickOne(random, skills.listSkills());
      final Map<String, Object?> stored = _findStoredSkill(
        simulated,
        skill.id,
      );
      final List<Object?> history = stored['history']! as List<Object?>;

      if (!_isAgentChangeNewest(history)) {
        await expectLater(
          skills.undoLatestAgentChange(skill.id),
          throwsStateError,
        );
        expect(skills.findSkill(skill.id).instructions, skill.instructions);
        continue;
      }

      final Map<String, Object?> latest =
          history.last! as Map<String, Object?>;
      final Skill restored = await skills.undoLatestAgentChange(skill.id);

      expect(restored.instructions, latest['replaced_instructions']);
      expect(restored.history.length, history.length - 1);
      expect(skills.findSkill(skill.id).instructions, restored.instructions);
      expect(
        _findStoredSkill(simulated, skill.id)['instructions'],
        latest['replaced_instructions'],
      );
    }
    skills.dispose();
  });
}
