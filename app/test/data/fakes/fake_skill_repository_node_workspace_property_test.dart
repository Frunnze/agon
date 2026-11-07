import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/library_values.dart' as node;
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/repository/skill_repository.dart';

import '../../support/random_inputs.dart';
import '../node_backed/support/simulated_catalog_node.dart';
import 'support/refusals.dart';
import 'support/rule_inputs.dart';
import 'support/skill_inputs.dart';
import 'support/workspace_inputs.dart';
import 'support/workspace_scope_inputs.dart';

const String _typePrefix = 'test_fake_skill_repository';
const int _sequenceIterations = 40;
const int _longestSequence = 12;
const int _largestSeededCount = 5;
const SkillId _missingSkillId = SkillId('skill-missing');

enum _Focus {
  listSkills('list_skills'),
  findSkill('find_skill'),
  createSkill('create_skill'),
  updateSkill('update_skill'),
  deleteSkill('delete_skill');

  const _Focus(this.methodName);

  final String methodName;
}

enum _SkillEdit { createSkill, updateSkill, deleteSkill }

typedef _Pair = ({
  FakeSkillRepository fake,
  NodeBackedSkillRepository nodeBacked,
  FakeWorkspaceRepository workspaces,
  List<WorkspaceId> workspaceIds,
});

typedef _Step = ({
  WorkspaceId? target,
  _SkillEdit edit,
  int at,
  SkillDraft draft,
});

bool _isSkillRefusal(Object error) {
  return error is ArgumentError ||
      error is StateError ||
      error is RecordNotFound;
}

Object? _encodeWire(Object? json) => jsonDecode(jsonEncode(json));

List<Skill> _seedSimulatedSkills(
  Random random,
  SimulatedCatalogNode simulated,
  List<WorkspaceId> workspaceIds,
) {
  final int count = random.nextInt(_largestSeededCount + 1);
  final List<Skill> skills = <Skill>[];
  for (int index = 0; index < count; index += 1) {
    final Map<String, Object?> wire = simulated.addSkill(
      workspaceId: pickOne(random, workspaceIds).value,
      name: 'seeded-${random.nextInt(4)}',
    );
    wire['scope'] = _encodeWire(
      mapScopeToNode(randomScopeOver(random, workspaceIds)).toJson(),
    );
    skills.add(mapSkillFromNode(node.Skill.fromJson(_encodeWire(wire))));
  }
  return skills;
}

Future<_Pair> _buildPair(Random random) async {
  final SeededWorkspaces seeded = seedRandomWorkspaces(random);
  final List<WorkspaceId> workspaceIds = listWorkspaceIds(seeded.workspaces);
  final SimulatedCatalogNode simulated = SimulatedCatalogNode(
    hasAccount: true,
  );
  final List<Skill> modelSkills = _seedSimulatedSkills(
    random,
    simulated,
    workspaceIds,
  );
  final NodeBackedSkillRepository nodeBacked = NodeBackedSkillRepository(
    channel: simulated.channel,
    workspaceRepository: seeded.repository,
  );
  await nodeBacked.load();
  return (
    fake: buildSkillRepositoryIn(modelSkills, seeded.repository),
    nodeBacked: nodeBacked,
    workspaces: seeded.repository,
    workspaceIds: workspaceIds,
  );
}

_SkillEdit _pickEdit(Random random, _Focus focus) {
  return switch (focus) {
    _Focus.createSkill => _SkillEdit.createSkill,
    _Focus.updateSkill => _SkillEdit.updateSkill,
    _Focus.deleteSkill => _SkillEdit.deleteSkill,
    _Focus.listSkills ||
    _Focus.findSkill => pickOne(random, _SkillEdit.values),
  };
}

_Step _planStep(Random random, _Pair pair, _Focus focus) {
  final int roll = random.nextInt(4);
  final bool isSwitch = roll == 0 || (focus == _Focus.listSkills && roll > 1);
  final SkillDraft named = randomSkillDraftNamed(
    random,
    pickOne(random, <String>[
      'seeded-${random.nextInt(4)}',
      randomValidSkillName(random),
      randomInvalidSkillName(random),
    ]),
  );
  return (
    target: isSwitch ? pickOne(random, pair.workspaceIds) : null,
    edit: roll == 1 ? _SkillEdit.createSkill : _pickEdit(random, focus),
    at: random.nextInt(pair.nodeBacked.listSkills().length + 1),
    draft: SkillDraft(
      name: named.name,
      summary: named.summary,
      instructions: named.instructions,
      scope: randomScopeOver(random, pair.workspaceIds),
      usage: named.usage,
      improvement: named.improvement,
    ),
  );
}

SkillId _pickSkillId(SkillRepository repository, int at) {
  final List<Skill> listed = repository.listSkills();
  if (at >= listed.length) {
    return _missingSkillId;
  }
  return listed[at].id;
}

Future<Object?> _applyEdit(SkillRepository repository, _Step step) {
  final SkillId skillId = _pickSkillId(repository, step.at);
  return switch (step.edit) {
    _SkillEdit.createSkill => repository.createSkill(step.draft),
    _SkillEdit.updateSkill => repository.updateSkill(skillId, step.draft),
    _SkillEdit.deleteSkill => repository.deleteSkill(skillId),
  };
}

Future<void> _applyStep(_Pair pair, _Step step) async {
  final WorkspaceId? target = step.target;
  if (target != null) {
    await pair.workspaces.switchWorkspace(target);
    return;
  }
  final bool isFakeRefused = await isRefused(
    () => _applyEdit(pair.fake, step),
    isRefusal: _isSkillRefusal,
  );
  final bool isNodeRefused = await isRefused(
    () => _applyEdit(pair.nodeBacked, step),
    isRefusal: _isSkillRefusal,
  );
  expect(isFakeRefused, isNodeRefused, reason: '${step.edit}');
}

String _describeContent(Skill skill) {
  return '${skill.name} ${skill.summary} ${skill.instructions} '
      '${skill.usage.name} ${skill.improvement.name} '
      '${describeScope(skill.scope)}';
}

void _expectSameFoundSkills(_Pair pair) {
  final List<Skill> fakeListing = pair.fake.listSkills();
  final List<Skill> nodeListing = pair.nodeBacked.listSkills();
  for (int index = 0; index < nodeListing.length; index += 1) {
    final Skill foundInFake = pair.fake.findSkill(fakeListing[index].id);
    final Skill foundInNode = pair.nodeBacked.findSkill(nodeListing[index].id);
    expect(_describeContent(foundInFake), _describeContent(foundInNode));
  }
}

List<String> _describeListing(SkillRepository repository) {
  return <String>[
    for (final Skill skill in repository.listSkills()) _describeContent(skill),
  ];
}

Future<void> _expectAgreementUnderFocus(_Focus focus, int seed) async {
  final Random random = seededRandom(seed);

  for (int i = 0; i < _sequenceIterations; i += 1) {
    final _Pair pair = await _buildPair(random);
    expect(_describeListing(pair.fake), _describeListing(pair.nodeBacked));
    final int stepCount = 1 + random.nextInt(_longestSequence);

    for (int step = 0; step < stepCount; step += 1) {
      await _applyStep(pair, _planStep(random, pair, focus));

      await pair.nodeBacked.load();
      expect(
        _describeListing(pair.fake),
        orderedEquals(_describeListing(pair.nodeBacked)),
      );
      _expectSameFoundSkills(pair);
    }
    pair.nodeBacked.dispose();
    pair.fake.dispose();
  }
}

void main() {
  for (final _Focus focus in _Focus.values) {
    test('${_typePrefix}_${focus.methodName}_property_agrees_with_the_node_'
        'across_workspaces', () async {
      await _expectAgreementUnderFocus(focus, 92301 + focus.index);
    });
  }
}
