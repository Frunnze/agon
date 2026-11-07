import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../../support/random_inputs.dart';
import '../../fakes/support/rule_inputs.dart';
import '../../fakes/support/skill_inputs.dart';
import '../../fakes/support/workspace_scope_inputs.dart';
import 'identifier_ordered_records.dart';
import 'out_of_order_replies.dart';
import 'reply_race_properties.dart';
import 'simulated_catalog_node.dart';
import 'simulated_node_replies.dart';

const List<String> _workspaceNames = <String>['home', 'lab', 'studio'];
const int _largestSeededSkillCount = 6;
const String _skillKind = 'skill';
const String _agentRunOrigin = 'approved_agent_run';
const Set<String> _skillChangeCommands = <String>{
  'create_skill',
  'update_skill',
  'undo_skill_change',
  'delete_skill',
};
const node.AreaChanged _skillsChanged = node.AreaChanged(
  area: node.ChangeArea.skills,
);

final class SkillReplyRace implements ReplyRace {
  SkillReplyRace._({
    required this.node,
    required this.transport,
    required this.announcements,
    required this.workspaces,
    required this.skills,
    required this.workspaceIds,
    required NodeCommandChannel reloadChannel,
  }) : _reloadChannel = reloadChannel;

  final SimulatedCatalogNode node;
  @override
  final OutOfOrderReplyTransport transport;
  final AnnouncingNodeAnswer announcements;
  final NodeBackedWorkspaceRepository workspaces;
  final NodeBackedSkillRepository skills;
  final List<WorkspaceId> workspaceIds;
  final NodeCommandChannel _reloadChannel;
  @override
  final PendingRaceWork pendingWork = PendingRaceWork();

  void announceSkillChange() {
    pendingWork.start(skills.applyChange(_skillsChanged));
  }

  @override
  void deliverWaitingAnnouncement() {
    if (announcements.waitingAnnouncements == 0) {
      return;
    }
    announcements.takeAnnouncement();
    announceSkillChange();
  }

  Future<void> _releaseEverything() {
    return releaseRepliesAndAnnouncements(
      transport: transport,
      announcements: announcements,
      deliverAnnouncement: announceSkillChange,
    );
  }

  @override
  Future<void> settle() async {
    await _releaseEverything();
    await pendingWork.finish();
    await _releaseEverything();
  }

  @override
  List<String> describeShown() => _describeSkills(skills.listSkills());

  @override
  List<String> listShownIdentifiers() {
    return <String>[
      for (final Skill skill in skills.listSkills()) skill.id.value,
    ];
  }

  @override
  Future<List<String>> describeReload() async {
    final NodeBackedSkillRepository reloaded = NodeBackedSkillRepository(
      channel: _reloadChannel,
      workspaceRepository: workspaces,
    );
    await reloaded.load();
    final List<String> listing = _describeSkills(reloaded.listSkills());
    reloaded.dispose();
    return listing;
  }

  @override
  void close() {
    skills.dispose();
    workspaces.dispose();
  }
}

List<String> _describeSkills(List<Skill> skills) {
  return <String>[
    for (final Skill skill in skills)
      '${describeSkill(skill)} ${describeScope(skill.scope)}',
  ];
}

Map<String, Object?> _randomAgentChangeJson(Random random) {
  return <String, Object?>{
    'origin': <String, Object?>{
      'kind': _agentRunOrigin,
      'run_id': 'run-${random.nextInt(1000)}',
    },
    'saved_at': '2026-10-20T09:00:00.000Z',
    'replaced_instructions': randomText(random),
  };
}

void _addSkillTo(
  Random random,
  SimulatedCatalogNode simulated,
  List<WorkspaceId> workspaceIds,
) {
  final Map<String, Object?> skill = simulated.addSkill(
    workspaceId: pickOne(random, workspaceIds).value,
    name: simulated.nextIdentifier('elsewhere'),
  );
  skill['id'] = randomRecordIdentifier(random, _skillKind);
  skill['scope'] = mapScopeToNode(randomScopeOver(random, workspaceIds))
      .toJson();
  skill['history'] = <Object?>[
    if (random.nextBool()) _randomAgentChangeJson(random),
  ];
}

Future<SkillReplyRace> openSkillReplyRace(Random random) async {
  final SimulatedCatalogNode simulated = SimulatedCatalogNode(
    hasAccount: true,
  );
  final List<WorkspaceId> workspaceIds = <WorkspaceId>[
    for (final String name in _workspaceNames)
      WorkspaceId(simulated.addWorkspace(name)['id']! as String),
  ];
  final int seededCount = random.nextInt(_largestSeededSkillCount);
  for (int i = 0; i < seededCount; i += 1) {
    _addSkillTo(random, simulated, workspaceIds);
  }
  final IdentifierOrderedCatalogNode ordered = IdentifierOrderedCatalogNode(
    simulated,
  );
  final AnnouncingNodeAnswer announcements = AnnouncingNodeAnswer(
    answer: ordered.answer,
    changeCommands: _skillChangeCommands,
  );
  final OutOfOrderReplyTransport transport = OutOfOrderReplyTransport(
    answer: announcements.answerAndAnnounce,
    random: random,
  );
  final NodeCommandChannel channel = NodeCommandChannel(transport: transport);
  final NodeBackedWorkspaceRepository workspaces = await openRaceWorkspaces(
    channel,
  );
  final NodeBackedSkillRepository skills = NodeBackedSkillRepository(
    channel: channel,
    workspaceRepository: workspaces,
  );
  await skills.load();
  transport.isHoldingReplies = true;
  return SkillReplyRace._(
    node: simulated,
    transport: transport,
    announcements: announcements,
    workspaces: workspaces,
    skills: skills,
    workspaceIds: workspaceIds,
    reloadChannel: buildSimulatedChannel(ordered.answer),
  );
}

SkillDraft _randomRaceSkillDraft(Random random, SkillReplyRace race) {
  final SkillDraft named = randomSkillDraftNamed(
    random,
    race.node.nextIdentifier('made'),
  );
  return SkillDraft(
    name: named.name,
    summary: named.summary,
    instructions: named.instructions,
    scope: randomScopeOver(random, race.workspaceIds),
    usage: named.usage,
    improvement: named.improvement,
  );
}

SkillId? _pickListedSkillId(Random random, SkillReplyRace race) {
  final List<Skill> listed = race.skills.listSkills();
  if (listed.isEmpty) {
    return null;
  }
  return pickOne(random, listed).id;
}

void createRaceSkill(Random random, SkillReplyRace race) {
  final SkillDraft draft = _randomRaceSkillDraft(random, race);
  race.pendingWork.start(race.skills.createSkill(draft));
}

void updateRaceSkill(Random random, SkillReplyRace race) {
  final SkillId? skillId = _pickListedSkillId(random, race);
  if (skillId == null) {
    return;
  }
  final SkillDraft draft = _randomRaceSkillDraft(random, race);
  race.pendingWork.start(race.skills.updateSkill(skillId, draft));
}

void undoRaceSkillChange(Random random, SkillReplyRace race) {
  final SkillId? skillId = _pickListedSkillId(random, race);
  if (skillId == null) {
    return;
  }
  race.pendingWork.start(race.skills.undoLatestAgentChange(skillId));
}

void deleteRaceSkill(Random random, SkillReplyRace race) {
  final SkillId? skillId = _pickListedSkillId(random, race);
  if (skillId == null) {
    return;
  }
  race.pendingWork.start(race.skills.deleteSkill(skillId));
}

void switchSkillRaceWorkspace(Random random, SkillReplyRace race) {
  final WorkspaceId currentWorkspaceId = race.workspaces.currentWorkspace().id;
  final List<Workspace> others = <Workspace>[
    for (final Workspace workspace in race.workspaces.listWorkspaces())
      if (workspace.id != currentWorkspaceId) workspace,
  ];
  race.pendingWork.start(
    race.workspaces.switchWorkspace(pickOne(random, others).id),
  );
}

void addSkillElsewhere(Random random, SkillReplyRace race) {
  _addSkillTo(random, race.node, race.workspaceIds);
  race.announceSkillChange();
}

void editSkillElsewhere(Random random, SkillReplyRace race) {
  if (race.node.skills.isEmpty) {
    return;
  }
  final Map<String, Object?> skill = pickOne(random, race.node.skills);
  skill['summary'] = randomText(random);
  skill['scope'] = mapScopeToNode(randomScopeOver(random, race.workspaceIds))
      .toJson();
  skill['history'] = <Object?>[
    ...skill['history']! as List<Object?>,
    _randomAgentChangeJson(random),
  ];
  race.announceSkillChange();
}

void deleteSkillElsewhere(Random random, SkillReplyRace race) {
  if (race.node.skills.isEmpty) {
    return;
  }
  race.node.skills.remove(pickOne(random, race.node.skills));
  race.announceSkillChange();
}
