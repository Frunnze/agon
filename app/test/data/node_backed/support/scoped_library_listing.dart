import 'dart:convert';
import 'dart:math';

import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../../bridge/support/scripted_node_transport.dart';
import '../../../support/memory_workspace_choice_store.dart';
import '../../../support/random_inputs.dart';
import 'node_backed_harness.dart';
import 'simulated_catalog_node.dart';
import 'simulated_scopes.dart';

const Duration _retryInterval = Duration(seconds: 30);
const String _listSkillsCommand = 'list_skills';
const String _creationWorkspaceField = 'workspace';
const List<String> _workspaceNames = <String>['home', 'lab'];

typedef ScopedLibrary = ({
  NodeCommandChannel channel,
  NodeBackedWorkspaceRepository workspaces,
  List<WorkspaceId> workspaceIds,
});

Object? _listSkillsByScope(
  SimulatedCatalogNode simulated,
  Object? workspaceId,
) {
  return <Object?>[
    for (final Map<String, Object?> skill in simulated.skills)
      if (isSimulatedScopeInWorkspace(skill, workspaceId))
        <String, Object?>{
          for (final MapEntry<String, Object?> field in skill.entries)
            if (field.key != _creationWorkspaceField) field.key: field.value,
        },
  ];
}

String _answerLikeTheNode(SimulatedCatalogNode simulated, String inputJson) {
  final Map<String, Object?> command =
      jsonDecode(inputJson) as Map<String, Object?>;
  if (command['command'] != _listSkillsCommand) {
    return simulated.answer(inputJson);
  }
  return encodeSuccessReply(
    _listSkillsByScope(simulated, command['workspace_id']),
  );
}

Future<ScopedLibrary> openScopedLibrary() async {
  final SimulatedCatalogNode simulated = SimulatedCatalogNode(
    hasAccount: true,
  );
  final List<WorkspaceId> workspaceIds = <WorkspaceId>[
    for (final String name in _workspaceNames)
      WorkspaceId(simulated.addWorkspace(name)['id']! as String),
  ];
  final NodeCommandChannel channel = buildSimulatedChannel(
    (String inputJson) => _answerLikeTheNode(simulated, inputJson),
  );
  final NodeBackedWorkspaceRepository workspaces =
      NodeBackedWorkspaceRepository(
        channel: channel,
        clock: FixedClock(DateTime.utc(2026, 11, 7)),
        retryInterval: _retryInterval,
        choiceStore: MemoryWorkspaceChoiceStore(chosenWorkspaceId: null),
      );
  await workspaces.load();
  return (
    channel: channel,
    workspaces: workspaces,
    workspaceIds: workspaceIds,
  );
}

Scope randomListingScope(Random random, List<WorkspaceId> workspaceIds) {
  final WorkspaceScope workspaces = random.nextInt(3) == 0
      ? const AllWorkspaces()
      : OnlyWorkspaces(<WorkspaceId>[
          for (final WorkspaceId workspaceId in workspaceIds)
            if (random.nextBool()) workspaceId,
        ]);
  final ProjectScope projects = random.nextBool()
      ? const AllProjects()
      : OnlyProjects(<ProjectId>[ProjectId('project-${randomText(random)}')]);
  return Scope(workspaces: workspaces, projects: projects);
}
