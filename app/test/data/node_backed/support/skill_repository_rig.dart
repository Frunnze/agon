import 'dart:convert';
import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/library_values.dart' as node;
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../../bridge/support/scripted_node_transport.dart';
import '../../../support/memory_workspace_choice_store.dart';
import '../../../support/random_inputs.dart';
import '../../fakes/support/notification_counter.dart';
import '../../fakes/support/skill_inputs.dart';
import '../../fakes/support/workspace_inputs.dart';
import 'held_next_reply_transport.dart';
import 'scoped_library_listing.dart';
import 'simulated_catalog_node.dart';
import 'simulated_scopes.dart';

const String listSkillsCommand = 'list_skills';
const String createSkillCommand = 'create_skill';
const String updateSkillCommand = 'update_skill';
const String undoSkillChangeCommand = 'undo_skill_change';
const String deleteSkillCommand = 'delete_skill';
const int rustKeptSkillChanges = 20;
const List<String> _workspaceNames = <String>['home', 'lab', 'studio'];
const List<String> _copiedSkillFields = <String>[
  'name',
  'summary',
  'instructions',
  'scope',
  'usage',
  'improvement',
];
const Duration _retryInterval = Duration(seconds: 30);
const int _largestSeededSkillCount = 5;

typedef SkillRig = ({
  RustLikeSkillNode node,
  HeldNextReplyTransport transport,
  NodeBackedWorkspaceRepository workspaces,
  List<WorkspaceId> workspaceIds,
  NodeBackedSkillRepository skills,
  NotificationCounter notifications,
});

final class RustLikeSkillNode {
  final SimulatedCatalogNode catalog = SimulatedCatalogNode(hasAccount: true);
  final List<String> receivedCommands = <String>[];
  String? refusal;

  String answer(String inputJson) {
    final Map<String, Object?> command =
        jsonDecode(inputJson) as Map<String, Object?>;
    final String commandName = command['command']! as String;
    receivedCommands.add(commandName);
    final String? currentRefusal = refusal;
    if (currentRefusal != null) {
      return encodeErrorReply(currentRefusal);
    }
    if (commandName == updateSkillCommand) {
      return _updateLikeRust(command);
    }
    return catalog.answer(inputJson);
  }

  int countCommands(String commandName) {
    int count = 0;
    for (final String sentName in receivedCommands) {
      if (sentName == commandName) {
        count += 1;
      }
    }
    return count;
  }

  List<String> listSkillIdsIn(WorkspaceId workspaceId) {
    return <String>[
      for (final Map<String, Object?> skill in catalog.skills)
        if (isSimulatedScopeInWorkspace(skill, workspaceId.value))
          skill['id']! as String,
    ];
  }

  String _updateLikeRust(Map<String, Object?> command) {
    Map<String, Object?>? skill;
    for (final Map<String, Object?> candidate in catalog.skills) {
      if (candidate['id'] == command['skill_id']) {
        skill = candidate;
      }
    }
    if (skill == null) {
      return encodeErrorReply('skill ${command['skill_id']} was not found');
    }

    final List<Object?> history = <Object?>[
      ...skill['history']! as List<Object?>,
    ];
    if (command['instructions'] != skill['instructions']) {
      history.add(<String, Object?>{
        'origin': <String, Object?>{'kind': 'person_edit'},
        'saved_at': skillClockMoment.toUtc().toIso8601String(),
        'replaced_instructions': skill['instructions'],
      });
    }
    final int excess = max(0, history.length - rustKeptSkillChanges);
    for (final String field in _copiedSkillFields) {
      skill[field] = command[field];
    }
    skill['history'] = history.sublist(excess);
    return encodeSuccessReply(skill);
  }
}

Future<SkillRig> openSkillRig(Random random) async {
  final RustLikeSkillNode simulated = RustLikeSkillNode();
  final List<WorkspaceId> workspaceIds = <WorkspaceId>[
    for (final String name in _workspaceNames)
      WorkspaceId(simulated.catalog.addWorkspace(name)['id']! as String),
  ];
  final int skillCount = random.nextInt(_largestSeededSkillCount);
  for (int i = 0; i < skillCount; i += 1) {
    final Map<String, Object?> skill = simulated.catalog.addSkill(
      workspaceId: pickOne(random, workspaceIds).value,
      name: 'seed-$i',
    );
    skill['scope'] = jsonDecode(
      jsonEncode(
        mapScopeToNode(randomListingScope(random, workspaceIds)).toJson(),
      ),
    );
  }

  final HeldNextReplyTransport transport = HeldNextReplyTransport(
    answer: simulated.answer,
  );
  final NodeCommandChannel channel = NodeCommandChannel(transport: transport);
  final NodeBackedWorkspaceRepository workspaces =
      NodeBackedWorkspaceRepository(
        channel: channel,
        clock: FixedClock(skillClockMoment),
        retryInterval: _retryInterval,
        choiceStore: MemoryWorkspaceChoiceStore(chosenWorkspaceId: null),
      );
  await workspaces.load();
  final NodeBackedSkillRepository skills = NodeBackedSkillRepository(
    channel: channel,
    workspaceRepository: workspaces,
  );
  final NotificationCounter notifications = NotificationCounter();
  skills.addListener(notifications.record);
  return (
    node: simulated,
    transport: transport,
    workspaces: workspaces,
    workspaceIds: workspaceIds,
    skills: skills,
    notifications: notifications,
  );
}

List<Skill> readNodeSkills(SkillRig rig) {
  return <Skill>[
    for (final Map<String, Object?> wire in rig.node.catalog.skills)
      mapSkillFromNode(node.Skill.fromJson(jsonDecode(jsonEncode(wire)))),
  ];
}

FakeSkillRepository buildTwinFakeSkills(SkillRig rig) {
  final FakeWorkspaceRepository fakeWorkspaces = buildWorkspaceRepository(
    workspaces: rig.workspaces.listWorkspaces(),
    currentWorkspaceId: rig.workspaces.currentWorkspace().id,
    appServerGroup: rig.workspaces.findAppServerGroup(),
  );
  return buildSkillRepositoryIn(readNodeSkills(rig), fakeWorkspaces);
}

List<String> listShownSkillIds(SkillRig rig) {
  return <String>[
    for (final Skill skill in rig.skills.listSkills()) skill.id.value,
  ];
}

List<String> listNodeSkillIdsHere(SkillRig rig) {
  return rig.node.listSkillIdsIn(rig.workspaces.currentWorkspace().id);
}

void closeSkillRig(SkillRig rig) {
  rig.skills.removeListener(rig.notifications.record);
  rig.skills.dispose();
  rig.workspaces.dispose();
}
