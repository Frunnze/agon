import 'dart:convert';
import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';

import '../../../bridge/support/scripted_node_transport.dart';
import '../../../support/random_inputs.dart';
import 'identifier_ordered_records.dart';
import 'node_backed_harness.dart'
    show buildSingleWorkspaceRepository, harnessWorkspaceId;
import 'out_of_order_replies.dart';
import 'reply_race_properties.dart';
import 'simulated_node_replies.dart';
import 'simulated_workflow_node.dart';
import 'simulated_workflow_views.dart';

const int _largestSeededWorkflowCount = 5;
const int _largestPollsBeforeDraftIsDone = 3;
const String _workflowKind = 'workflow';
const String _createWorkflowCommand = 'create_workflow';
const List<String> _seededStates = <String>[
  signedState,
  changedState,
  unsignedState,
];
const Set<String> _workflowChangeCommands = <String>{
  _createWorkflowCommand,
  'save_workflow',
  'sign_workflow',
  'discard_workflow_change',
  'delete_workflow',
  'workflow_draft_status',
};
const node.AreaChanged _workflowsChanged = node.AreaChanged(
  area: node.ChangeArea.workflows,
);

typedef SimulatedWorkflowView = Map<String, Object?>;

SimulatedRecord readSimulatedWorkflow(SimulatedWorkflowView view) {
  return view['workflow']! as SimulatedRecord;
}

int _compareViewIdentifiers(
  SimulatedWorkflowView first,
  SimulatedWorkflowView second,
) {
  return compareSimulatedIdentifiers(
    readSimulatedWorkflow(first),
    readSimulatedWorkflow(second),
  );
}

final class IdentifierOrderedWorkflowNode {
  IdentifierOrderedWorkflowNode({
    required this.workflows,
    required this.random,
  });

  final SimulatedWorkflowNode workflows;
  final Random random;

  String answer(String inputJson) {
    workflows.views.sort(_compareViewIdentifiers);
    final SimulatedCommand command = jsonDecode(inputJson) as SimulatedCommand;
    if (command['command'] == _createWorkflowCommand) {
      return encodeSuccessReply(_createWorkflow(command));
    }
    return workflows.answer(inputJson);
  }

  SimulatedWorkflowView _createWorkflow(SimulatedCommand command) {
    final SimulatedRecord workflow = <String, Object?>{
      'id': randomRecordIdentifier(random, _workflowKind),
      'name': command['name'],
      'availability': command['availability'],
      'agents': command['agents'],
      'connections': command['connections'],
      'signature': null,
    };
    final SimulatedWorkflowView view = buildSimulatedWorkflowView(
      workflow,
      unsignedState,
    );
    workflows.views.add(view);
    return view;
  }

  void addWorkflowElsewhere() {
    final SimulatedWorkflowView view = workflows.addWorkflow(
      name: 'elsewhere-${random.nextInt(1000)}',
      state: pickOne(random, _seededStates),
    );
    readSimulatedWorkflow(view)['id'] = randomRecordIdentifier(
      random,
      _workflowKind,
    );
  }
}

final class WorkflowReplyRace implements ReplyRace {
  WorkflowReplyRace._({
    required this.node,
    required this.transport,
    required this.announcements,
    required this.workspaces,
    required this.workflows,
    required NodeCommandChannel reloadChannel,
  }) : _reloadChannel = reloadChannel;

  final IdentifierOrderedWorkflowNode node;
  @override
  final OutOfOrderReplyTransport transport;
  final AnnouncingNodeAnswer announcements;
  final WorkspaceRepository workspaces;
  final NodeBackedWorkflowRepository workflows;
  final NodeCommandChannel _reloadChannel;
  @override
  final PendingRaceWork pendingWork = PendingRaceWork();

  void announceWorkflowChange() {
    pendingWork.start(workflows.applyChange(_workflowsChanged));
  }

  @override
  void deliverWaitingAnnouncement() {
    if (announcements.waitingAnnouncements == 0) {
      return;
    }
    announcements.takeAnnouncement();
    announceWorkflowChange();
  }

  Future<void> _releaseEverything() {
    return releaseRepliesAndAnnouncements(
      transport: transport,
      announcements: announcements,
      deliverAnnouncement: announceWorkflowChange,
    );
  }

  @override
  Future<void> settle() async {
    await _releaseEverything();
    await pendingWork.finish();
    await _releaseEverything();
  }

  @override
  List<String> describeShown() => _describeWorkflows(workflows);

  @override
  List<String> listShownIdentifiers() {
    return <String>[
      for (final Workflow workflow in workflows.listWorkflows())
        workflow.id.value,
    ];
  }

  @override
  Future<List<String>> describeReload() async {
    final NodeBackedWorkflowRepository reloaded = NodeBackedWorkflowRepository(
      channel: _reloadChannel,
      workspaceRepository: workspaces,
      draftPollInterval: Duration.zero,
    );
    await reloaded.load();
    final List<String> described = _describeWorkflows(reloaded);
    reloaded.dispose();
    return described;
  }

  @override
  void close() {
    workflows.dispose();
  }
}

String _describeAgent(WorkflowAgent agent) {
  return '${agent.id.value}:${agent.name}:${agent.kind?.name}:${agent.task}';
}

List<String> _describeWorkflows(NodeBackedWorkflowRepository workflows) {
  final List<String> described = <String>[];
  for (final Workflow workflow in workflows.listWorkflows()) {
    final WorkflowChange? change = workflows.findPendingChange(workflow.id);
    final List<String> agents = <String>[
      for (final WorkflowAgent agent in workflow.agents) _describeAgent(agent),
    ];
    described.add(
      '${workflow.id.value}|${workflow.name}|'
      '${mapWorkspaceScopeToNode(workflow.availability).toJson()}|'
      '${agents.join(',')}|${workflow.signature != null}|'
      '${change?.summary}',
    );
  }
  return described;
}

void _seedWorkflows(Random random, IdentifierOrderedWorkflowNode ordered) {
  final int seededCount = random.nextInt(_largestSeededWorkflowCount);
  for (int i = 0; i < seededCount; i += 1) {
    ordered.addWorkflowElsewhere();
  }
}

Future<WorkflowReplyRace> openWorkflowReplyRace(Random random) async {
  final SimulatedWorkflowNode simulated = SimulatedWorkflowNode(
    pollsBeforeDraftIsDone: random.nextInt(_largestPollsBeforeDraftIsDone),
  );
  final IdentifierOrderedWorkflowNode ordered = IdentifierOrderedWorkflowNode(
    workflows: simulated,
    random: random,
  );
  _seedWorkflows(random, ordered);
  final AnnouncingNodeAnswer announcements = AnnouncingNodeAnswer(
    answer: ordered.answer,
    changeCommands: _workflowChangeCommands,
  );
  final OutOfOrderReplyTransport transport = OutOfOrderReplyTransport(
    answer: announcements.answerAndAnnounce,
    random: random,
  );
  final WorkspaceRepository workspaces = buildSingleWorkspaceRepository();
  final NodeBackedWorkflowRepository workflows = NodeBackedWorkflowRepository(
    channel: NodeCommandChannel(transport: transport),
    workspaceRepository: workspaces,
    draftPollInterval: Duration.zero,
  );
  await workflows.load();
  transport.isHoldingReplies = true;
  return WorkflowReplyRace._(
    node: ordered,
    transport: transport,
    announcements: announcements,
    workspaces: workspaces,
    workflows: workflows,
    reloadChannel: buildSimulatedChannel(ordered.answer),
  );
}

WorkspaceScope randomRaceAvailability(Random random) {
  return pickOne(random, <WorkspaceScope>[
    const AllWorkspaces(),
    OnlyWorkspaces(const <WorkspaceId>[harnessWorkspaceId]),
    OnlyWorkspaces(const <WorkspaceId>[WorkspaceId('workspace-elsewhere')]),
  ]);
}
