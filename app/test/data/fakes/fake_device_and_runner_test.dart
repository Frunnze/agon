import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_runners.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';

const List<WorkspaceId> _workspaceIds = <WorkspaceId>[
  GalleryWorkspaceIds.acme,
  GalleryWorkspaceIds.personal,
];

FakeDeviceRepository buildGalleryDeviceRepository() {
  return FakeDeviceRepository(
    devices: galleryDevices,
    currentDeviceId: GalleryDeviceIds.airLaptop,
    peerAddressProblem: null,
  );
}

FakeRunnerRepository _buildGalleryRunnerRepository() {
  return FakeRunnerRepository(
    runners: galleryRunners,
    thisDeviceOffers: null,
    thisRunnerProblem: null,
  );
}

void main() {
  test('test_list_devices_property_count_is_stable', () async {
    final Random random = seededRandom(801);
    final FakeDeviceRepository repository = buildGalleryDeviceRepository();

    for (int i = 0; i < propertyIterations; i += 1) {
      final Device device = pickOne(random, galleryDevices);
      await repository.addDeviceToWorkspace(
        device.id,
        pickOne(random, _workspaceIds),
      );
      expect(repository.listDevices().length, galleryDevices.length);
    }
  });

  test('test_find_device_property_finds_every_seeded_device', () {
    final Random random = seededRandom(802);
    final FakeDeviceRepository repository = buildGalleryDeviceRepository();

    for (int i = 0; i < propertyIterations; i += 1) {
      final Device device = pickOne(random, galleryDevices);
      expect(repository.findDevice(device.id).name, device.name);
    }
    expect(
      () => repository.findDevice(const DeviceId('missing')),
      throwsA(isA<RecordNotFound>()),
    );
  });

  test('test_current_device_property_is_air_laptop', () async {
    final Random random = seededRandom(803);
    final FakeDeviceRepository repository = buildGalleryDeviceRepository();

    for (int i = 0; i < propertyIterations; i += 1) {
      final Device other = pickOne(random, galleryDevices.skip(1).toList());
      await repository.revokeDevice(other.id);
      expect(repository.currentDevice().name, 'air-laptop');
    }
  });

  test('test_revoke_device_property_never_this_device', () async {
    final Random random = seededRandom(804);
    final FakeDeviceRepository repository = buildGalleryDeviceRepository();

    for (int i = 0; i < propertyIterations; i += 1) {
      final Device device = pickOne(random, galleryDevices);
      if (device.id == GalleryDeviceIds.airLaptop) {
        await expectLater(
          repository.revokeDevice(device.id),
          throwsA(isA<StateError>()),
        );
      } else {
        expect((await repository.revokeDevice(device.id)).revoked, isTrue);
      }
    }
  });

  test('test_add_device_to_workspace_property_no_duplicates', () async {
    final Random random = seededRandom(805);
    final FakeDeviceRepository repository = buildGalleryDeviceRepository();

    for (int i = 0; i < propertyIterations; i += 1) {
      final Device device = pickOne(random, galleryDevices);
      final WorkspaceId workspaceId = pickOne(random, _workspaceIds);
      final Device after = await repository.addDeviceToWorkspace(
        device.id,
        workspaceId,
      );

      expect(after.workspaces.where((w) => w == workspaceId).length, 1);
    }
  });

  test('test_remove_device_from_workspace_property_workspace_gone', () async {
    final Random random = seededRandom(806);
    final FakeDeviceRepository repository = buildGalleryDeviceRepository();

    for (int i = 0; i < propertyIterations; i += 1) {
      final Device device = pickOne(random, galleryDevices);
      final WorkspaceId workspaceId = pickOne(random, _workspaceIds);
      final Device after = await repository.removeDeviceFromWorkspace(
        device.id,
        workspaceId,
      );

      expect(after.workspaces.contains(workspaceId), isFalse);
    }
  });

  test('test_list_runners_property_count_is_stable', () async {
    final Random random = seededRandom(807);
    final FakeRunnerRepository repository = _buildGalleryRunnerRepository();

    for (int i = 0; i < propertyIterations; i += 1) {
      final Runner runner = pickOne(random, galleryRunners);
      await repository.pauseRunner(runner.deviceId);
      expect(repository.listRunners().length, galleryRunners.length);
    }
  });

  test('test_find_runner_property_finds_every_seeded_runner', () {
    final Random random = seededRandom(808);
    final FakeRunnerRepository repository = _buildGalleryRunnerRepository();

    for (int i = 0; i < propertyIterations; i += 1) {
      final Runner runner = pickOne(random, galleryRunners);
      expect(repository.findRunner(runner.deviceId).labels, runner.labels);
    }
    expect(
      () => repository.findRunner(const DeviceId('missing')),
      throwsA(isA<RecordNotFound>()),
    );
  });

  test('test_pause_runner_property_stops_new_runs', () async {
    final Random random = seededRandom(809);
    final FakeRunnerRepository repository = _buildGalleryRunnerRepository();

    for (int i = 0; i < propertyIterations; i += 1) {
      final Runner runner = pickOne(random, galleryRunners);
      final Runner paused = await repository.pauseRunner(runner.deviceId);
      expect(paused.acceptingNewRuns, isFalse);
      expect(paused.slotsTotal, runner.slotsTotal);
    }
  });

  test('test_resume_runner_property_accepts_new_runs', () async {
    final Random random = seededRandom(810);
    final FakeRunnerRepository repository = _buildGalleryRunnerRepository();

    for (int i = 0; i < propertyIterations; i += 1) {
      final Runner runner = pickOne(random, galleryRunners);
      await repository.pauseRunner(runner.deviceId);
      final Runner resumed = await repository.resumeRunner(runner.deviceId);
      expect(resumed.acceptingNewRuns, isTrue);
    }
  });

  test(
    'test_choose_agent_offers_property_fake_shows_the_chosen_offers',
    () async {
      final Random random = seededRandom(811);

      for (int i = 0; i < propertyIterations; i += 1) {
        final String problem = 'blocked ${randomText(random)}';
        final FakeRunnerRepository repository = FakeRunnerRepository(
          runners: galleryRunners,
          thisDeviceOffers: <PlaceOffer>[
            PlaceOffer(place: AgentPlace.container, problem: problem),
          ],
          thisRunnerProblem: problem,
        );
        final List<AgentPlace> chosen = <AgentPlace>[
          for (final AgentPlace place in AgentPlace.values)
            if (random.nextBool()) place,
        ];
        if (chosen.isEmpty) {
          chosen.add(AgentPlace.container);
        }

        await repository.chooseAgentOffers(chosen);

        final List<PlaceOffer> expectedOffers = <PlaceOffer>[
          for (final AgentPlace place in chosen)
            PlaceOffer(
              place: place,
              problem: place == AgentPlace.container ? problem : null,
            ),
        ];
        expect(repository.findThisDeviceOffers(), expectedOffers);
        final String? expectedProblem =
            chosen.contains(AgentPlace.localProcess) ? null : problem;
        expect(repository.findThisRunnerProblem(), expectedProblem);
      }
    },
  );

  test('test_choose_agent_offers_property_fake_without_agents_refuses', () {
    final Random random = seededRandom(812);
    final FakeRunnerRepository repository = _buildGalleryRunnerRepository();

    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentPlace place = pickOne(random, AgentPlace.values);
      expect(
        repository.chooseAgentOffers(<AgentPlace>[place]),
        throwsA(isA<StateError>()),
      );
    }
  });
}
