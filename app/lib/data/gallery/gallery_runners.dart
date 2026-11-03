import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';

const List<String> _allowedHosts = <String>['api.anthropic.com', 'github.com'];

final List<Runner> galleryRunners = List<Runner>.unmodifiable(<Runner>[
  Runner(
    deviceId: GalleryDeviceIds.macStudio,
    labels: const <String>['mac', 'arm64', 'xcode'],
    slotsTotal: 4,
    slotsBusy: 1,
    link: RunnerLink.direct,
    online: true,
    acceptingNewRuns: true,
    offers: const <AgentPlace>[AgentPlace.container],
    allowedHosts: _allowedHosts,
  ),
  Runner(
    deviceId: GalleryDeviceIds.officeServer,
    labels: const <String>['linux', 'x64'],
    slotsTotal: 2,
    slotsBusy: 1,
    link: RunnerLink.direct,
    online: true,
    acceptingNewRuns: true,
    offers: const <AgentPlace>[AgentPlace.container],
    allowedHosts: _allowedHosts,
  ),
  Runner(
    deviceId: GalleryDeviceIds.gpuBox,
    labels: const <String>['gpu', 'cuda'],
    slotsTotal: 1,
    slotsBusy: 0,
    link: RunnerLink.relay,
    online: true,
    acceptingNewRuns: true,
    offers: const <AgentPlace>[AgentPlace.container],
    allowedHosts: _allowedHosts,
  ),
  Runner(
    deviceId: GalleryDeviceIds.oldMacbook,
    labels: const <String>['mac'],
    slotsTotal: 2,
    slotsBusy: 0,
    link: RunnerLink.unreachable,
    online: false,
    acceptingNewRuns: true,
    offers: const <AgentPlace>[AgentPlace.localProcess],
    allowedHosts: _allowedHosts,
  ),
]);
