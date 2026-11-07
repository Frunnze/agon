import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../../support/random_inputs.dart';
import '../../fakes/support/project_inputs.dart';
import 'identifier_ordered_records.dart';
import 'out_of_order_replies.dart';
import 'project_reply_race.dart' show addProjectElsewhere, describeProject;
import 'reply_race_properties.dart';
import 'simulated_catalog_node.dart';
import 'simulated_node_replies.dart';

const List<String> _workspaceNames = <String>['home', 'lab', 'studio'];
const int _largestSeededProjectCount = 6;
const String _workspaceKind = 'workspace';
const String _projectKind = 'project';
const Set<String> _projectChangeCommands = <String>{
  'create_project',
  'delete_project',
};
const node.AreaChanged _projectsChanged = node.AreaChanged(
  area: node.ChangeArea.projects,
);

final class OrderedProjectReplyRace implements ReplyRace {
  OrderedProjectReplyRace._({
    required this.node,
    required this.transport,
    required this.announcements,
    required this.workspaces,
    required this.projects,
    required NodeCommandChannel reloadChannel,
  }) : _reloadChannel = reloadChannel;

  final SimulatedCatalogNode node;
  @override
  final OutOfOrderReplyTransport transport;
  final AnnouncingNodeAnswer announcements;
  final NodeBackedWorkspaceRepository workspaces;
  final NodeBackedProjectRepository projects;
  final NodeCommandChannel _reloadChannel;
  @override
  final PendingRaceWork pendingWork = PendingRaceWork();

  void announceProjectChange() {
    pendingWork.start(projects.applyChange(_projectsChanged));
  }

  @override
  void deliverWaitingAnnouncement() {
    if (announcements.waitingAnnouncements == 0) {
      return;
    }
    announcements.takeAnnouncement();
    announceProjectChange();
  }

  Future<void> _releaseEverything() {
    return releaseRepliesAndAnnouncements(
      transport: transport,
      announcements: announcements,
      deliverAnnouncement: announceProjectChange,
    );
  }

  @override
  Future<void> settle() async {
    await _releaseEverything();
    await pendingWork.finish();
    await _releaseEverything();
  }

  @override
  List<String> describeShown() => _describeProjects(projects, workspaces);

  @override
  List<String> listShownIdentifiers() {
    return <String>[
      for (final Workspace workspace in workspaces.listWorkspaces())
        for (final Project project in projects.listProjects(workspace.id))
          '${workspace.id.value} ${project.id.value}',
    ];
  }

  @override
  Future<List<String>> describeReload() async {
    final NodeBackedProjectRepository reloaded = NodeBackedProjectRepository(
      channel: _reloadChannel,
      workspaceRepository: workspaces,
    );
    await reloaded.load();
    final List<String> described = _describeProjects(reloaded, workspaces);
    reloaded.dispose();
    return described;
  }

  @override
  void close() {
    projects.dispose();
    workspaces.dispose();
  }
}

List<String> _describeProjects(
  NodeBackedProjectRepository projects,
  NodeBackedWorkspaceRepository workspaces,
) {
  return <String>[
    for (final Workspace workspace in workspaces.listWorkspaces())
      for (final Project project in projects.listProjects(workspace.id))
        describeProject(project),
  ];
}

void _addOrderedProjectElsewhere(Random random, SimulatedCatalogNode node) {
  addProjectElsewhere(random, node);
  node.projects.last['id'] = randomRecordIdentifier(random, _projectKind);
}

Future<OrderedProjectReplyRace> openOrderedProjectReplyRace(
  Random random,
) async {
  final SimulatedCatalogNode simulated = SimulatedCatalogNode(
    hasAccount: true,
  );
  for (final String name in _workspaceNames) {
    simulated.addWorkspace(name);
  }
  giveRandomIdentifiers(random, simulated.workspaces, kind: _workspaceKind);
  final int seededCount = random.nextInt(_largestSeededProjectCount);
  for (int i = 0; i < seededCount; i += 1) {
    _addOrderedProjectElsewhere(random, simulated);
  }
  final IdentifierOrderedCatalogNode ordered = IdentifierOrderedCatalogNode(
    simulated,
  );
  final AnnouncingNodeAnswer announcements = AnnouncingNodeAnswer(
    answer: ordered.answer,
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
  return OrderedProjectReplyRace._(
    node: simulated,
    transport: transport,
    announcements: announcements,
    workspaces: workspaces,
    projects: projects,
    reloadChannel: buildSimulatedChannel(ordered.answer),
  );
}

void createOrderedRaceProject(Random random, OrderedProjectReplyRace race) {
  final ProjectDraft draft = ProjectDraft(
    workspaceId: pickOne(random, race.workspaces.listWorkspaces()).id,
    name: 'made-${random.nextInt(1000)}',
    repositories: randomDistinctRepositories(random),
    approvalPolicy: null,
  );
  race.pendingWork.start(race.projects.createProject(draft));
}

void addOrderedProjectElsewhere(Random random, OrderedProjectReplyRace race) {
  _addOrderedProjectElsewhere(random, race.node);
  race.announceProjectChange();
}

void deleteOrderedProjectElsewhere(
  Random random,
  OrderedProjectReplyRace race,
) {
  if (race.node.projects.isEmpty) {
    return;
  }
  race.node.projects.remove(pickOne(random, race.node.projects));
  race.announceProjectChange();
}
