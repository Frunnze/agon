import 'dart:math';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/skill_change.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/data/rules/naming.dart';

import '../../../support/fake_task_work_links.dart';
import '../../../support/random_inputs.dart';

const String seededSkillIdPrefix = 'seeded-skill-';
const String createdSkillIdPrefix = 'created-skill-';
const int _largestSeededSkillCount = 5;
const int _largestHistoryLength = 4;
const String _nameCharacters = 'abcdefghijklmnopqrstuvwxyz0123456789-';
const List<String> _invalidSkillNames = <String>[
  '',
  ' ',
  'Release',
  'ios release',
  'ios_release',
  ' ios-release',
  'ios-release ',
  'café',
  'Ünïcødé',
  'tab\tname',
  'line\nbreak',
  'a.b',
];

final DateTime skillClockMoment = galleryNow;

String randomValidSkillName(Random random) {
  final int length = 1 + random.nextInt(nameMaximumLength);
  final StringBuffer buffer = StringBuffer();

  for (int i = 0; i < length; i += 1) {
    final int index = random.nextInt(_nameCharacters.length);
    buffer.write(_nameCharacters[index]);
  }

  return buffer.toString();
}

String randomInvalidSkillName(Random random) {
  if (random.nextBool()) {
    return pickOne(random, _invalidSkillNames);
  }
  final String tooLong = 'a' * (nameMaximumLength + 1 + random.nextInt(9));
  return tooLong;
}

SkillDraft randomSkillDraftNamed(Random random, String name) {
  return SkillDraft(
    name: name,
    summary: randomText(random),
    instructions: randomText(random),
    scope: const Scope.everywhere(),
    usage: pickOne(random, SkillUsage.values),
    improvement: pickOne(random, SkillImprovement.values),
  );
}

SkillChangeOrigin randomSkillChangeOrigin(Random random) {
  final RunId runId = RunId('run-${random.nextInt(1000)}');
  return pickOne(random, <SkillChangeOrigin>[
    const PersonEdit(),
    ApprovedAgentRun(runId),
    AutomaticAgentRun(runId),
  ]);
}

List<SkillChange> randomSkillHistory(Random random) {
  final int count = random.nextInt(_largestHistoryLength);
  return <SkillChange>[
    for (int i = 0; i < count; i += 1)
      SkillChange(
        origin: randomSkillChangeOrigin(random),
        savedAt: randomUtcMoment(random),
        replacedInstructions: 'Version $i ${randomText(random)}',
      ),
  ];
}

Skill randomSeededSkill(Random random, int index) {
  return Skill(
    id: SkillId('$seededSkillIdPrefix$index'),
    name: 'seeded-$index',
    summary: randomText(random),
    instructions: randomText(random),
    scope: const Scope.everywhere(),
    usage: pickOne(random, SkillUsage.values),
    source: pickOne(random, SkillSource.values),
    improvement: pickOne(random, SkillImprovement.values),
    history: randomSkillHistory(random),
  );
}

List<Skill> randomSeededSkills(Random random) {
  final int count = random.nextInt(_largestSeededSkillCount);
  return <Skill>[
    for (int index = 0; index < count; index += 1)
      randomSeededSkill(random, index),
  ];
}

FakeSkillRepository buildSkillRepositoryIn(
  List<Skill> skills,
  WorkspaceRepository workspaceRepository,
) {
  return FakeSkillRepository(
    skills: skills,
    clock: FixedClock(skillClockMoment),
    workspaceRepository: workspaceRepository,
  );
}

FakeSkillRepository buildSkillRepository(List<Skill> skills) {
  return buildSkillRepositoryIn(skills, buildAcmeWorkspaceRepository());
}

String describeSkill(Skill skill) {
  final List<String> fields = <String>[
    skill.id.value,
    skill.name,
    skill.summary,
    skill.instructions,
    skill.usage.name,
    skill.source.name,
    skill.improvement.name,
    '${skill.history.length}',
  ];
  return fields.join('|');
}

List<String> describeSkills(List<Skill> skills) {
  final List<String> descriptions = <String>[];
  for (final Skill skill in skills) {
    descriptions.add(describeSkill(skill));
  }
  return descriptions;
}

bool isSkillNameListed(List<Skill> skills, String name) {
  for (final Skill skill in skills) {
    if (skill.name == name) {
      return true;
    }
  }
  return false;
}
