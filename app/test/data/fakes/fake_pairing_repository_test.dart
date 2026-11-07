import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_pairing.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/data/rules/naming.dart';
import 'package:agent_orchestration/data/rules/setup_input_rules.dart';

import '../../support/random_inputs.dart';

const String _serverAddress = 'https://relay.acme.dev';

final class PairingFixture {
  PairingFixture(Duration elapsed)
    : deviceRepository = FakeDeviceRepository(
        devices: galleryDevices,
        currentDeviceId: GalleryDeviceIds.airLaptop,
        peerAddressProblem: null,
        gitlessFolderPaths: const <String>{},
      ) {
    pairingRepository = FakePairingRepository(
      session: galleryPairingSession,
      request: galleryPairingRequest,
      clock: FixedClock(galleryNow.add(elapsed)),
      deviceRepository: deviceRepository,
      joinOutcome: galleryPairingOutcome,
      startedPairingRendezvousProblem: null,
    );
  }

  final FakeDeviceRepository deviceRepository;
  late final FakePairingRepository pairingRepository;
}

List<WorkspaceId> randomWorkspaceChoice(Random random) {
  final List<WorkspaceId> chosen = <WorkspaceId>[
    if (random.nextBool()) GalleryWorkspaceIds.personal,
  ];
  if (chosen.isEmpty || random.nextBool()) {
    chosen.insert(0, GalleryWorkspaceIds.acme);
  }
  return chosen;
}

void main() {
  test('test_find_active_session_property_none_after_expiry', () {
    final Random random = seededRandom(901);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Duration elapsed = Duration(seconds: random.nextInt(600));
      final FakePairingRepository repository = PairingFixture(elapsed)
          .pairingRepository;
      final bool isLive = galleryPairingSession.expiresAt.isAfter(
        galleryNow.add(elapsed),
      );

      expect(repository.findActiveSession() != null, isLive);
    }
  });

  test('test_start_pairing_property_five_minute_session', () async {
    final Random random = seededRandom(902);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakePairingRepository repository = PairingFixture(
        Duration(minutes: random.nextInt(60)),
      ).pairingRepository;
      final PairingSession session = await repository.startPairing();

      expect(
        session.expiresAt.difference(session.createdAt),
        const Duration(minutes: 5),
      );
      expect(repository.findPendingRequest(), isNull);
    }
  });

  test('test_find_pending_request_property_cleared_by_decision', () async {
    final Random random = seededRandom(903);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakePairingRepository repository = PairingFixture(Duration.zero)
          .pairingRepository;
      expect(repository.findPendingRequest()?.deviceName, 'mac-mini');
      if (random.nextBool()) {
        await repository.rejectPairing();
      } else {
        await repository.approvePairing(randomWorkspaceChoice(random));
      }
      expect(repository.findPendingRequest(), isNull);
    }
  });

  test('test_approve_pairing_property_adds_the_device_to_the_list', () async {
    final Random random = seededRandom(904);

    for (int i = 0; i < propertyIterations; i += 1) {
      final PairingFixture fixture = PairingFixture(Duration.zero);
      final List<WorkspaceId> workspaces = randomWorkspaceChoice(random);
      final Device device = await fixture.pairingRepository.approvePairing(
        workspaces,
      );

      expect(device.role, galleryPairingRequest.role);
      expect(device.keyKind, galleryPairingRequest.keyKind);
      expect(device.workspaces, workspaces);
      expect(device.approvedBy, GalleryDeviceIds.airLaptop);
      expect(fixture.deviceRepository.findDevice(device.id).name, 'mac-mini');
      expect(
        fixture.deviceRepository.listDevices().length,
        galleryDevices.length + 1,
      );
      await expectLater(
        fixture.pairingRepository.approvePairing(workspaces),
        throwsA(isA<StateError>()),
      );
    }
  });

  test('test_approve_pairing_fuzz_property_no_workspace_fails', () async {
    final FakePairingRepository repository = PairingFixture(Duration.zero)
        .pairingRepository;

    for (int i = 0; i < propertyIterations; i += 1) {
      await expectLater(
        repository.approvePairing(const <WorkspaceId>[]),
        throwsArgumentError,
      );
    }
    expect(repository.findPendingRequest(), isNotNull);
  });

  test('test_reject_pairing_property_second_reject_fails', () async {
    final FakePairingRepository repository = PairingFixture(Duration.zero)
        .pairingRepository;

    await repository.rejectPairing();
    for (int i = 0; i < propertyIterations; i += 1) {
      await expectLater(
        repository.rejectPairing(),
        throwsA(isA<StateError>()),
      );
    }
  });

  test(
    'test_join_with_code_property_valid_code_and_any_given_server_accepted',
    () async {
      final Random random = seededRandom(906);
      final FakePairingRepository repository = PairingFixture(Duration.zero)
          .pairingRepository;

      for (int i = 0; i < propertyIterations; i += 1) {
        final String code = randomText(random);
        final String? serverAddress = pickOne(random, <String?>[
          _serverAddress,
          randomText(random),
          null,
        ]);
        final DeviceRole role = pickOne(random, DeviceRole.values);
        final bool isValid =
            describePairingCodeProblem(code) == null &&
            (serverAddress == null ||
                describeServerAddressProblem(serverAddress) == null);
        final Future<PairingOutcome> joining = repository.joinWithCode(
          serverAddress: serverAddress,
          code: code,
          deviceName: 'mac-mini',
          role: role,
        );

        if (isValid) {
          final PairingOutcome outcome = await joining;
          expect(outcome.role, role);
          expect(outcome.deviceName, 'mac-mini');
        } else {
          await expectLater(joining, throwsA(isA<FormatException>()));
        }
      }
      final PairingOutcome outcome = await repository.joinWithCode(
        serverAddress: _serverAddress,
        code: '4f7 k2q',
        deviceName: 'studio-two',
        role: DeviceRole.runner,
      );
      expect(outcome.deviceName, 'studio-two');
      expect(outcome.workspaceNames, <String>['acme']);
      expect(outcome.runnerLabels, <String>['mac', 'arm64']);
      expect(outcome.approverName, 'air-laptop');
    },
  );

  test(
    'test_create_hosted_account_property_first_device_of_the_workspace',
    () async {
      final Random random = seededRandom(907);
      final FakePairingRepository repository = PairingFixture(Duration.zero)
          .pairingRepository;

      for (int i = 0; i < propertyIterations; i += 1) {
        final String workspaceName = random.nextBool()
            ? 'acme-${random.nextInt(99)}'
            : randomText(random);
        final DeviceRole role = pickOne(random, DeviceRole.values);
        final bool isValid = describeNameProblem(workspaceName) == null;
        final Future<PairingOutcome> creating = repository.createHostedAccount(
          workspaceName: workspaceName,
          deviceName: 'new-mac',
          role: role,
        );

        if (isValid) {
          final PairingOutcome outcome = await creating;
          expect(outcome.workspaceNames, <String>[workspaceName]);
          expect(outcome.role, role);
          expect(outcome.deviceName, 'new-mac');
          expect(outcome.approverName, isNull);
        } else {
          await expectLater(creating, throwsArgumentError);
        }
      }
    },
  );

  test(
    'test_create_hosted_account_fuzz_property_bad_device_names_fail',
    () async {
      final Random random = seededRandom(908);
      final FakePairingRepository repository = PairingFixture(Duration.zero)
          .pairingRepository;

      for (int i = 0; i < propertyIterations; i += 1) {
        final String deviceName = 'Bad Name ${randomText(random)}';

        await expectLater(
          repository.createHostedAccount(
            workspaceName: 'acme',
            deviceName: deviceName,
            role: DeviceRole.client,
          ),
          throwsArgumentError,
        );
      }
    },
  );

  test('test_cancel_pairing_property_clears_only_a_showing_code', () async {
    final Random random = seededRandom(909);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakePairingRepository repository = PairingFixture(
        Duration(seconds: random.nextInt(600)),
      ).pairingRepository;

      if (repository.findActiveSession() == null) {
        await expectLater(repository.cancelPairing(), throwsStateError);
        continue;
      }
      await repository.cancelPairing();
      expect(repository.findActiveSession(), isNull);
      expect(repository.findPendingRequest(), isNull);
      await expectLater(repository.cancelPairing(), throwsStateError);
    }
  });
}
