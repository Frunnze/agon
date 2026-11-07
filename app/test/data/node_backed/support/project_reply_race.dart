import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../../support/random_inputs.dart';
import '../../fakes/support/project_inputs.dart';
import 'out_of_order_replies.dart';
import 'simulated_catalog_node.dart';

const List<String> _workspaceNames = <String>['home', 'lab'];
const int _largestSeededProjectCount = 4;
const Set<String> _projectChangeCommands = <String>{
  'create_project',
  'create_repository',
  'remove_repository',
  'delete_project',
};
const node.AreaChanged _projectsChanged = node.AreaChanged(
  area: node.ChangeArea.projects,
);

typedef ProjectReplyRace = ({
  SimulatedCatalogNode node,
  OutOfOrderReplyTransport transport,
  AnnouncingNodeAnswer announcements,
  NodeBackedWorkspaceRepository workspaces,
  NodeBackedProjectRepository projects,
  PendingRaceWork pendingWork,
});

Map<String, Object?> _encodeRepository(Repository repository) {
  return mapRepositoryToNode(repository).toJson();
}

void addProjectElsewhere(Random random, SimulatedCatalogNode simulated) {
  final Map<String, Object?> workspace = pickOne(random, simulated.workspaces);
  simulated.projects.add(<String, Object?>{
    'id': simulated.nextIdentifier('project'),
    'workspace_id': workspace['id'],
    'name': 'elsewhere-${random.nextInt(1000)}',
    'repositories': <Object?>[
      for (final Repository repository in randomDistinctRepositories(random))
        _encodeRepository(repository),
    ],
    'approval_policy': null,
  });
}

Future<ProjectReplyRace> openProjectReplyRace(Random random) async {
  final SimulatedCatalogNode simulated = SimulatedCatalogNode(
    hasAccount: true,
  );
  for (final String name in _workspaceNames) {
    simulated.addWorkspace(name);
  }
  final int seededCount = random.nextInt(_largestSeededProjectCount);
  for (int i = 0; i < seededCount; i += 1) {
    addProjectElsewhere(random, simulated);
  }
  final AnnouncingNodeAnswer announcements = AnnouncingNodeAnswer(
    answer: simulated.answer,
    changeCommands: _projectChangeCommands,
  );
  final OutOfOrderReplyTransport transport = OutOfOrderReplyTransport(
    answer: announcements.answerAndAnnounce,
    random: random,
  );
  final NodeCommandChannel channel = NodeCommandChannel(transport: transport);
  final NodeBackedWorkspaceRepository workspaces = await openRaceWorkspaces(
    channel,
  );
  final NodeBackedProjectRepository projects = NodeBackedProjectRepository(
    channel: channel,
    workspaceRepository: workspaces,
  );
  await projects.load();
  transport.isHoldingReplies = true;
  return (
    node: simulated,
    transport: transport,
    announcements: announcements,
    workspaces: workspaces,
    projects: projects,
    pendingWork: PendingRaceWork(),
  );
}

List<Project> listEveryProject(
  NodeBackedProjectRepository projects,
  NodeBackedWorkspaceRepository workspaces,
) {
  return <Project>[
    for (final Workspace workspace in workspaces.listWorkspaces())
      ...projects.listProjects(workspace.id),
  ];
}

Project? pickListedProject(Random random, ProjectReplyRace race) {
  final List<Project> listed = listEveryProject(
    race.projects,
    race.workspaces,
  );
  if (listed.isEmpty) {
    return null;
  }
  return pickOne(random, listed);
}

void announceProjectChange(ProjectReplyRace race) {
  race.pendingWork.start(race.projects.applyChange(_projectsChanged));
}

void deliverWaitingProjectAnnouncement(ProjectReplyRace race) {
  if (race.announcements.waitingAnnouncements == 0) {
    return;
  }
  race.announcements.takeAnnouncement();
  announceProjectChange(race);
}

void addRepositoryElsewhere(Random random, ProjectReplyRace race) {
  if (race.node.projects.isEmpty) {
    return;
  }
  final Map<String, Object?> project = pickOne(random, race.node.projects);
  final List<Object?> repositories = project['repositories']! as List<Object?>;
  final Repository repository = randomRepositoryAt(
    random,
    randomCanonicalAddress(random),
  );
  project['repositories'] = <Object?>[
    ...repositories,
    _encodeRepository(repository),
  ];
  announceProjectChange(race);
}

void changeProjectsElsewhere(Random random, ProjectReplyRace race) {
  if (random.nextBool() || race.node.projects.isEmpty) {
    addProjectElsewhere(random, race.node);
  } else {
    race.node.projects.remove(pickOne(random, race.node.projects));
  }
  announceProjectChange(race);
}

Future<void> _releaseEverything(ProjectReplyRace race) {
  return releaseRepliesAndAnnouncements(
    transport: race.transport,
    announcements: race.announcements,
    deliverAnnouncement: () => announceProjectChange(race),
  );
}

String _describeRepository(Repository repository) {
  return '${repository.address}|${repository.defaultBranch}|'
      '${repository.agentAccess.name}';
}

String describeProject(Project project) {
  final List<String> repositories = <String>[
    for (final Repository repository in project.repositories)
      _describeRepository(repository),
  ];
  return '${project.id.value} ${project.workspaceId.value} ${project.name} '
      '${project.approvalPolicy?.name} ${repositories.join(',')}';
}

List<String> describeSortedProjects(List<Project> projects) {
  final List<String> described = <String>[
    for (final Project project in projects) describeProject(project),
  ];
  described.sort();
  return described;
}

Future<List<String>> finishProjectReplyRace(ProjectReplyRace race) async {
  await _releaseEverything(race);
  await race.pendingWork.finish();
  await _releaseEverything(race);
  return describeSortedProjects(
    listEveryProject(race.projects, race.workspaces),
  );
}

Future<List<String>> reloadProjectsFrom(
  NodeCommandChannel channel,
  NodeBackedWorkspaceRepository workspaces,
) async {
  final NodeBackedProjectRepository reloaded = NodeBackedProjectRepository(
    channel: channel,
    workspaceRepository: workspaces,
  );
  await reloaded.load();
  final List<String> listing = describeSortedProjects(
    listEveryProject(reloaded, workspaces),
  );
  reloaded.dispose();
  return listing;
}

void closeProjectReplyRace(ProjectReplyRace race) {
  race.projects.dispose();
  race.workspaces.dispose();
}

WorkspaceId pickRaceWorkspaceId(Random random, ProjectReplyRace race) {
  return pickOne(random, race.workspaces.listWorkspaces()).id;
}
