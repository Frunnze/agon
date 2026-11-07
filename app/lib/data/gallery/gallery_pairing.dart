import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/data/models/runner.dart';

const String _pairingCode = '4F7-K2Q';
const Duration _pairingLifetime = Duration(minutes: 5);
const Duration _pairingAge = Duration(seconds: 8);

final PairingSession galleryPairingSession = PairingSession(
  code: _pairingCode,
  createdAt: galleryNow.subtract(_pairingAge),
  expiresAt: galleryNow.subtract(_pairingAge).add(_pairingLifetime),
  rendezvousProblem: null,
);

final PairingRequest galleryPairingRequest = PairingRequest(
  deviceName: 'mac-mini',
  role: DeviceRole.runner,
  keyKind: HardwareKeyKind.secureEnclave,
  codeUsed: _pairingCode,
  fingerprintWords: const <String>['maple', 'orbit', 'cinder', 'lamp'],
  link: RunnerLink.localNetwork,
);

final PairingOutcome galleryPairingOutcome = PairingOutcome(
  deviceName: 'mac-mini',
  role: DeviceRole.runner,
  workspaceNames: const <String>['acme'],
  runnerLabels: const <String>['mac', 'arm64'],
  approverName: 'air-laptop',
);
