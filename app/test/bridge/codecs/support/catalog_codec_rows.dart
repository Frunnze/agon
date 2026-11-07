import 'package:agent_orchestration/bridge/codecs/catalog_views.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';

import '../../support/random_catalog_json.dart';
import 'codec_rows.dart';

const List<ConstructorRow> catalogConstructorRows = <ConstructorRow>[
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'workspace_view',
      buildJson: randomWorkspaceViewJson,
      decode: WorkspaceView.fromJson,
    ),
    rebuild: _rebuildWorkspaceView,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'project_view',
      buildJson: randomProjectViewJson,
      decode: ProjectView.fromJson,
    ),
    rebuild: _rebuildProjectView,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'runner_summary',
      buildJson: randomRunnerSummaryJson,
      decode: RunnerSummary.fromJson,
    ),
    rebuild: _rebuildRunnerSummary,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'runner_view',
      buildJson: randomRunnerViewJson,
      decode: RunnerView.fromJson,
    ),
    rebuild: _rebuildRunnerView,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'place_offer',
      buildJson: randomPlaceOfferJson,
      decode: PlaceOffer.fromJson,
    ),
    rebuild: _rebuildPlaceOffer,
  ),
];

const List<EncodableRow> catalogEncodableRows = <EncodableRow>[
  EncodableRow(
    typeName: 'device_view',
    buildJson: randomDeviceViewJson,
    decode: DeviceView.fromJson,
  ),
  EncodableRow(
    typeName: 'runners_view',
    buildJson: randomRunnersViewJson,
    decode: RunnersView.fromJson,
  ),
];

JsonEncodable _rebuildWorkspaceView(JsonEncodable value) {
  final WorkspaceView view = value as WorkspaceView;
  return WorkspaceView(
    workspace: view.workspace,
    projectCount: view.projectCount,
    runnerCount: view.runnerCount,
  );
}

JsonEncodable _rebuildProjectView(JsonEncodable value) {
  final ProjectView view = value as ProjectView;
  return ProjectView(
    project: view.project,
    taskCount: view.taskCount,
    runningTaskCount: view.runningTaskCount,
  );
}

JsonEncodable _rebuildRunnerSummary(JsonEncodable value) {
  final RunnerSummary summary = value as RunnerSummary;
  return RunnerSummary(
    runnerCount: summary.runnerCount,
    onlineCount: summary.onlineCount,
    freeSlotCount: summary.freeSlotCount,
  );
}

JsonEncodable _rebuildRunnerView(JsonEncodable value) {
  final RunnerView view = value as RunnerView;
  return RunnerView(
    runner: view.runner,
    deviceName: view.deviceName,
    freeSlots: view.freeSlots,
    peerAddressVerified: view.peerAddressVerified,
  );
}

JsonEncodable _rebuildPlaceOffer(JsonEncodable value) {
  final PlaceOffer offer = value as PlaceOffer;
  return PlaceOffer(place: offer.place, problem: offer.problem);
}
