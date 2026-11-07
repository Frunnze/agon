import 'dart:convert';
import 'dart:math';

import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';

import '../../../bridge/support/random_account_json.dart';
import '../../../bridge/support/scripted_node_transport.dart';
import '../../../support/memory_workspace_choice_store.dart';
import '../../../support/random_inputs.dart';
import '../../fakes/support/notification_counter.dart';
import '../../fakes/support/runner_inputs.dart';
import '../../fakes/support/workspace_inputs.dart';
import 'held_next_reply_transport.dart';
import 'simulated_catalog_node.dart';
import 'simulated_device_node.dart';
import 'simulated_work_node.dart' show WireRecord;

const String listRunnersCommand = 'list_runners';
const String chooseAgentOffersCommand = 'choose_agent_offers';
const String rustNoOffersMessage =
    'a runner offers at least one place for agents to run';
const String _localPlaceWireName = 'local_process';
const String _containerPlaceWireName = 'container';
const List<String> _wirePlacesInRustOrder = <String>[
  _localPlaceWireName,
  _containerPlaceWireName,
];
const int _largestSeededRunnerCount = 6;
const Duration _retryInterval = Duration(seconds: 30);

typedef RunnerRig = ({
  ScopedRunnerNode node,
  FakeWorkspaceRepository workspaces,
  List<WorkspaceId> workspaceIds,
  HeldNextReplyTransport transport,
  NodeBackedRunnerRepository repository,
  NotificationCounter notifications,
});

final class ScopedRunnerNode {
  final SimulatedDeviceNode device = SimulatedDeviceNode(thisDeviceId: 'me');
  final Map<String, WorkspaceId> runnerWorkspaces = <String, WorkspaceId>{};
  final List<Object?> listedWorkspaceIds = <Object?>[];
  String? refusal;

  String answer(String inputJson) {
    final WireRecord command = jsonDecode(inputJson) as WireRecord;
    final String commandName = command['command']! as String;
    final String? currentRefusal = refusal;
    if (currentRefusal != null) {
      device.receivedCommands.add(commandName);
      return encodeErrorReply(currentRefusal);
    }
    if (commandName == chooseAgentOffersCommand) {
      device.receivedCommands.add(commandName);
      return _chooseOffersLikeRust(command);
    }

    final String reply = device.answer(inputJson);
    if (commandName != listRunnersCommand) {
      return reply;
    }
    listedWorkspaceIds.add(command['workspace_id']);
    return _keepRunnersOf(reply, command['workspace_id']);
  }

  String addRunnerIn(Random random, WorkspaceId workspaceId) {
    final String deviceId = device.addRunnerFromElsewhere(random);
    runnerWorkspaces[deviceId] = workspaceId;
    return deviceId;
  }

  List<String> listRunnerIdsIn(WorkspaceId workspaceId) {
    return <String>[
      for (final String deviceId in device.runners.keys)
        if (runnerWorkspaces[deviceId] == workspaceId) deviceId,
    ];
  }

  void seedThisDevice(Random random) {
    final bool canRun = random.nextBool();
    final List<WireRecord> offers = <WireRecord>[
      for (final PlaceOffer offer in randomPlaceOffers(random))
        <String, Object?>{
          'place': _wireNameOf(offer.place),
          'problem': offer.problem,
        },
    ];
    device.runnerSettings = canRun ? randomRunnerSettingsJson(random) : null;
    device.runnerOffers = canRun ? offers : null;
    device.runnerProblem = canRun ? findRustBlockingProblem(offers) : null;
  }

  String _keepRunnersOf(String reply, Object? workspaceId) {
    final WireRecord decoded = jsonDecode(reply) as WireRecord;
    final WireRecord? view = decoded['ok'] as WireRecord?;
    if (view == null) {
      return reply;
    }
    final List<Object?> runnerViews = view['runners']! as List<Object?>;
    view['runners'] = <Object?>[
      for (final Object? runnerView in runnerViews)
        if (_isRunnerViewIn(runnerView, workspaceId)) runnerView,
    ];
    return jsonEncode(decoded);
  }

  bool _isRunnerViewIn(Object? runnerView, Object? workspaceId) {
    final WireRecord fields = runnerView! as WireRecord;
    final WireRecord runner = fields['runner']! as WireRecord;
    return runnerWorkspaces[runner['device_id']]?.value == workspaceId;
  }

  String _chooseOffersLikeRust(WireRecord command) {
    if (device.runnerSettings == null) {
      return encodeErrorReply(simulatedNotARunnerMessage);
    }
    final List<Object?> chosen = command['offers']! as List<Object?>;
    if (chosen.isEmpty) {
      return encodeErrorReply(rustNoOffersMessage);
    }

    final List<WireRecord> offers = <WireRecord>[
      for (final String place in _wirePlacesInRustOrder)
        if (chosen.contains(place))
          <String, Object?>{'place': place, 'problem': _checkedProblem(place)},
    ];
    device.runnerOffers = offers;
    device.runnerProblem = findRustBlockingProblem(offers);
    return encodeSuccessReply(null);
  }

  String? _checkedProblem(String place) {
    for (final WireRecord offer in device.runnerOffers ?? <WireRecord>[]) {
      if (offer['place'] == place) {
        return offer['problem'] as String?;
      }
    }
    return null;
  }
}

String? findRustBlockingProblem(List<WireRecord> offers) {
  if (offers.isEmpty) {
    return null;
  }
  for (final WireRecord offer in offers) {
    if (offer['problem'] == null) {
      return null;
    }
  }
  return offers.first['problem'] as String?;
}

String _wireNameOf(AgentPlace place) {
  return switch (place) {
    AgentPlace.localProcess => _localPlaceWireName,
    AgentPlace.container => _containerPlaceWireName,
  };
}

RunnerRig buildRunnerRig(Random random) {
  final ScopedRunnerNode simulated = ScopedRunnerNode();
  final SeededWorkspaces seeded = seedRandomWorkspaces(random);
  final List<WorkspaceId> workspaceIds = <WorkspaceId>[
    for (final Workspace workspace in seeded.workspaces) workspace.id,
  ];
  final int runnerCount = random.nextInt(_largestSeededRunnerCount);
  for (int i = 0; i < runnerCount; i += 1) {
    simulated.addRunnerIn(random, pickOne(random, workspaceIds));
  }
  simulated.seedThisDevice(random);

  final HeldNextReplyTransport transport = HeldNextReplyTransport(
    answer: simulated.answer,
  );
  final NodeBackedRunnerRepository repository = NodeBackedRunnerRepository(
    channel: NodeCommandChannel(transport: transport),
    workspaceRepository: seeded.repository,
  );
  final NotificationCounter notifications = NotificationCounter();
  repository.addListener(notifications.record);
  return (
    node: simulated,
    workspaces: seeded.repository,
    workspaceIds: workspaceIds,
    transport: transport,
    repository: repository,
    notifications: notifications,
  );
}

Future<WorkspaceRepository> openWorkspacelessRepository() async {
  final SimulatedCatalogNode catalog = SimulatedCatalogNode(hasAccount: true);
  final NodeBackedWorkspaceRepository workspaces =
      NodeBackedWorkspaceRepository(
        channel: catalog.channel,
        clock: FixedClock(DateTime.utc(2026, 11, 7)),
        retryInterval: _retryInterval,
        choiceStore: MemoryWorkspaceChoiceStore(chosenWorkspaceId: null),
      );
  await workspaces.load();
  return workspaces;
}

List<String> listShownRunnerIds(RunnerRig rig) {
  return <String>[
    for (final Runner runner in rig.repository.listRunners())
      runner.deviceId.value,
  ];
}

List<String> listNodeRunnerIdsHere(RunnerRig rig) {
  return rig.node.listRunnerIdsIn(rig.workspaces.currentWorkspace().id);
}

int countCommands(RunnerRig rig, String commandName) {
  int count = 0;
  for (final String sentName in rig.node.device.receivedCommands) {
    if (sentName == commandName) {
      count += 1;
    }
  }
  return count;
}

void closeRunnerRig(RunnerRig rig) {
  rig.repository.removeListener(rig.notifications.record);
  rig.repository.dispose();
  rig.workspaces.dispose();
}
