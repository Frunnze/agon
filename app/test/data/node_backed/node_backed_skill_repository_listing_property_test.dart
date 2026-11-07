import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/rules/scope_rules.dart';

import '../../support/random_inputs.dart';
import 'support/scoped_library_listing.dart';

typedef _OpenedSkills = ({
  ScopedLibrary library,
  NodeBackedSkillRepository skills,
});

const int _seededSkillCount = 6;

Future<_OpenedSkills> _openSkills() async {
  final ScopedLibrary library = await openScopedLibrary();
  final NodeBackedSkillRepository skills = NodeBackedSkillRepository(
    channel: library.channel,
    workspaceRepository: library.workspaces,
  );
  await skills.load();
  return (library: library, skills: skills);
}

Map<SkillId, String> _describeListing(List<Skill> skills) {
  return <SkillId, String>{
    for (final Skill skill in skills) skill.id: skill.summary,
  };
}

Future<Map<SkillId, String>> _reloadListing(ScopedLibrary library) async {
  final NodeBackedSkillRepository reloaded = NodeBackedSkillRepository(
    channel: library.channel,
    workspaceRepository: library.workspaces,
  );
  await reloaded.load();
  final Map<SkillId, String> listing = _describeListing(reloaded.listSkills());
  reloaded.dispose();
  return listing;
}

SkillDraft _randomDraft(Random random, ScopedLibrary library, String name) {
  return SkillDraft(
    name: name,
    summary: 'Summary ${randomText(random)}',
    instructions: randomText(random),
    scope: randomListingScope(random, library.workspaceIds),
    usage: pickOne(random, SkillUsage.values),
    improvement: pickOne(random, SkillImprovement.values),
  );
}

bool _isListedHere(ScopedLibrary library, SkillDraft draft) {
  return includesWorkspace(
    draft.scope.workspaces,
    library.workspaces.currentWorkspace().id,
  );
}

Future<List<Skill>> _createSeededSkills(
  Random random,
  _OpenedSkills opened,
) async {
  final List<Skill> created = <Skill>[];
  for (int i = 0; i < _seededSkillCount; i += 1) {
    final SkillDraft draft = _randomDraft(random, opened.library, 'seed-$i');
    created.add(await opened.skills.createSkill(draft));
  }
  return created;
}

void _close(_OpenedSkills opened) {
  opened.skills.dispose();
  opened.library.workspaces.dispose();
}

void main() {
  test(
    'test_store_skill_property_created_skills_list_like_a_reload',
    () async {
      final Random random = seededRandom(66401);
      final _OpenedSkills opened = await _openSkills();

      for (int i = 0; i < propertyIterations; i += 1) {
        final SkillDraft draft = _randomDraft(
          random,
          opened.library,
          'new-$i',
        );
        await opened.skills.createSkill(draft);

        expect(
          _describeListing(opened.skills.listSkills()),
          await _reloadListing(opened.library),
        );
      }
      _close(opened);
    },
  );

  test(
    'test_store_skill_property_updated_skills_list_like_a_reload',
    () async {
      final Random random = seededRandom(66402);
      final _OpenedSkills opened = await _openSkills();
      final List<Skill> seeded = await _createSeededSkills(random, opened);

      for (int i = 0; i < propertyIterations; i += 1) {
        final Skill target = pickOne(random, seeded);
        await opened.skills.updateSkill(
          target.id,
          _randomDraft(random, opened.library, target.name),
        );

        expect(
          _describeListing(opened.skills.listSkills()),
          await _reloadListing(opened.library),
        );
      }
      _close(opened);
    },
  );

  test('test_store_skill_property_only_skills_for_this_workspace_are_'
      'found', () async {
    final Random random = seededRandom(66403);
    final _OpenedSkills opened = await _openSkills();
    final List<Skill> seeded = await _createSeededSkills(random, opened);

    for (int i = 0; i < propertyIterations; i += 1) {
      final bool isUpdate = random.nextBool();
      final Skill target = pickOne(random, seeded);
      final String name = isUpdate ? target.name : 'new-$i';
      final SkillDraft draft = _randomDraft(random, opened.library, name);
      final Skill saved = isUpdate
          ? await opened.skills.updateSkill(target.id, draft)
          : await opened.skills.createSkill(draft);

      if (_isListedHere(opened.library, draft)) {
        expect(opened.skills.findSkill(saved.id).summary, draft.summary);
      } else {
        expect(
          () => opened.skills.findSkill(saved.id),
          throwsA(isA<RecordNotFound>()),
        );
      }
    }
    _close(opened);
  });
}
