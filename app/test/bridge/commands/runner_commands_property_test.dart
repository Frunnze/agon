import 'dart:math';

import 'package:agent_orchestration/bridge/commands/runner_commands.dart';
import 'package:agent_orchestration/bridge/node/runner_settings.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../support/random_inputs.dart';
import '../support/hostile_texts.dart';
import '../support/list_copy_properties.dart';
import '../support/node_wire_names.dart';
import '../support/random_catalog_json.dart';
import '../support/simple_command_properties.dart';
import 'support/drafting_and_file_command_properties.dart';
import 'support/library_and_live_reply_properties.dart';

const int _firstMemberSeed = 7365000;
const int _firstReplySeed = 7366000;
const int _offersCopySeed = 7367000;
const int _seedsPerNothingReply = 10;
const int _largestOfferCount = 6;

const List<String> _nothingReplyCommandNames = <String>[
  'pause_runner',
  'choose_agent_offers',
  'resume_runner',
];

const List<ModelledCommandRow> _runnerCommandRows = <ModelledCommandRow>[
  ModelledCommandRow(
    typeName: 'list_runners_command',
    commandName: 'list_runners',
    build: _buildListRunners,
  ),
  ModelledCommandRow(
    typeName: 'pause_runner_command',
    commandName: 'pause_runner',
    build: _buildPauseRunner,
  ),
  ModelledCommandRow(
    typeName: 'choose_agent_offers_command',
    commandName: 'choose_agent_offers',
    build: _buildChooseAgentOffers,
  ),
  ModelledCommandRow(
    typeName: 'resume_runner_command',
    commandName: 'resume_runner',
    build: _buildResumeRunner,
  ),
];

const List<ReplyRow> _objectReplyRows = <ReplyRow>[
  ReplyRow(
    typeName: 'list_runners_command',
    commandName: 'list_runners',
    buildObjectJson: randomRunnersViewJson,
    requiredFields: <String>['summary', 'summary_text', 'runners'],
  ),
];

void main() {
  testModelledCommandRows(_runnerCommandRows, _firstMemberSeed);
  testObjectReplyRows(_objectReplyRows, _firstReplySeed);
  for (int i = 0; i < _nothingReplyCommandNames.length; i += 1) {
    final String commandName = _nothingReplyCommandNames[i];
    testNothingReplyProperties(
      typeName: '${commandName}_command',
      seed: _firstReplySeed + (i + 1) * _seedsPerNothingReply,
      buildCommand: findCommandShape(commandName).buildCommand,
    );
  }
  testListCopyProperties(
    const ListCopy<ChooseAgentOffersCommand, AgentPlace>(
      testNamePrefix: 'test_choose_agent_offers_command_constructor_property',
      seed: _offersCopySeed,
      buildElement: _randomAgentPlace,
      construct: _buildChooseAgentOffersWith,
      readList: _readOffers,
    ),
  );
}

ModelledCommand _buildListRunners(Random random) {
  final WorkspaceId workspaceId = WorkspaceId(randomHostileText(random));
  final ListRunnersCommand command = ListRunnersCommand(
    workspaceId: workspaceId,
  );
  return (
    command: command,
    givenFields: <Object?>[workspaceId],
    keptFields: <Object?>[command.workspaceId],
    expectedArguments: <String, Object?>{'workspace_id': workspaceId.value},
  );
}

ModelledCommand _buildPauseRunner(Random random) {
  final DeviceId deviceId = DeviceId(randomHostileText(random));
  final PauseRunnerCommand command = PauseRunnerCommand(deviceId: deviceId);
  return (
    command: command,
    givenFields: <Object?>[deviceId],
    keptFields: <Object?>[command.deviceId],
    expectedArguments: <String, Object?>{'device_id': deviceId.value},
  );
}

ModelledCommand _buildChooseAgentOffers(Random random) {
  final int offerCount = random.nextInt(_largestOfferCount);
  final List<String> offerNames = <String>[];
  final List<AgentPlace> offers = <AgentPlace>[];
  for (int i = 0; i < offerCount; i += 1) {
    final String offerName = pickOne(random, nodeAgentPlaces);
    offerNames.add(offerName);
    offers.add(AgentPlace.decode(offerName));
  }
  final ChooseAgentOffersCommand command = ChooseAgentOffersCommand(
    offers: offers,
  );
  return (
    command: command,
    givenFields: <Object?>[...offers],
    keptFields: <Object?>[...command.offers],
    expectedArguments: <String, Object?>{'offers': offerNames},
  );
}

ModelledCommand _buildResumeRunner(Random random) {
  final DeviceId deviceId = DeviceId(randomHostileText(random));
  final ResumeRunnerCommand command = ResumeRunnerCommand(deviceId: deviceId);
  return (
    command: command,
    givenFields: <Object?>[deviceId],
    keptFields: <Object?>[command.deviceId],
    expectedArguments: <String, Object?>{'device_id': deviceId.value},
  );
}

AgentPlace _randomAgentPlace(Random random) {
  return AgentPlace.decode(pickOne(random, nodeAgentPlaces));
}

ChooseAgentOffersCommand _buildChooseAgentOffersWith(
  Random random,
  List<AgentPlace> offers,
) {
  return ChooseAgentOffersCommand(offers: offers);
}

List<AgentPlace> _readOffers(ChooseAgentOffersCommand command) {
  return command.offers;
}
