import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/catalog_views.dart';
import 'package:agent_orchestration/bridge/codecs/device_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';

import '../../support/random_inputs.dart';
import '../support/list_copy_properties.dart';
import '../support/random_catalog_json.dart';
import '../support/wire_codec_properties.dart';

const List<WireCodec> _catalogCodecs = <WireCodec>[
  WireCodec(
    typeName: 'device_view',
    seed: 49700,
    buildJson: randomDeviceViewJson,
    decode: DeviceView.fromJson,
    requiredFields: <String>{
      'device',
      'is_this_device',
      'workspace_names',
      'peer_address_verified',
    },
    optionalFields: <String>{},
  ),
  WireCodec(
    typeName: 'workspace_view',
    seed: 49710,
    buildJson: randomWorkspaceViewJson,
    decode: WorkspaceView.fromJson,
    requiredFields: <String>{'workspace', 'project_count', 'runner_count'},
    optionalFields: <String>{},
  ),
  WireCodec(
    typeName: 'project_view',
    seed: 49720,
    buildJson: randomProjectViewJson,
    decode: ProjectView.fromJson,
    requiredFields: <String>{'project', 'task_count', 'running_task_count'},
    optionalFields: <String>{},
  ),
  WireCodec(
    typeName: 'runner_summary',
    seed: 49730,
    buildJson: randomRunnerSummaryJson,
    decode: RunnerSummary.fromJson,
    requiredFields: <String>{
      'runner_count',
      'online_count',
      'free_slot_count',
    },
    optionalFields: <String>{},
  ),
  WireCodec(
    typeName: 'runner_view',
    seed: 49740,
    buildJson: randomRunnerViewJson,
    decode: RunnerView.fromJson,
    requiredFields: <String>{
      'runner',
      'device_name',
      'free_slots',
      'peer_address_verified',
    },
    optionalFields: <String>{},
  ),
  WireCodec(
    typeName: 'runners_view',
    seed: 49750,
    buildJson: randomRunnersViewJson,
    decode: RunnersView.fromJson,
    requiredFields: <String>{'summary', 'summary_text', 'runners'},
    optionalFields: <String>{
      'this_device_problem',
      'this_device_settings',
      'this_device_offers',
    },
  ),
  WireCodec(
    typeName: 'place_offer',
    seed: 49760,
    buildJson: randomPlaceOfferJson,
    decode: PlaceOffer.fromJson,
    requiredFields: <String>{'place'},
    optionalFields: <String>{'problem'},
  ),
];

void main() {
  for (final WireCodec codec in _catalogCodecs) {
    testWireDecodingProperties(codec);
    testWireEncodingProperties(codec);
  }

  testListCopyProperties(
    const ListCopy<DeviceView, String>(
      testNamePrefix: 'test_device_view_constructor_property_workspace_names',
      seed: 49770,
      buildElement: randomText,
      construct: _buildDeviceView,
      readList: _readWorkspaceNames,
    ),
  );

  testListCopyProperties(
    const ListCopy<RunnersView, RunnerView>(
      testNamePrefix: 'test_runners_view_constructor_property_runners',
      seed: 49780,
      buildElement: _buildRunnerView,
      construct: _buildRunnersView,
      readList: _readRunners,
    ),
  );
}

DeviceView _buildDeviceView(Random random, List<String> workspaceNames) {
  return DeviceView(
    device: Device.fromJson(randomDeviceJson(random)),
    isThisDevice: random.nextBool(),
    workspaceNames: workspaceNames,
    peerAddressVerified: random.nextBool(),
  );
}

List<String> _readWorkspaceNames(DeviceView view) => view.workspaceNames;

RunnerView _buildRunnerView(Random random) {
  return RunnerView.fromJson(randomRunnerViewJson(random));
}

RunnersView _buildRunnersView(Random random, List<RunnerView> runners) {
  final JsonObject summaryJson = randomRunnerSummaryJson(random);
  return RunnersView(
    summary: RunnerSummary.fromJson(summaryJson),
    summaryText: randomText(random),
    runners: runners,
    thisDeviceProblem: null,
    thisDeviceSettings: null,
    thisDeviceOffers: null,
  );
}

List<RunnerView> _readRunners(RunnersView view) => view.runners;
