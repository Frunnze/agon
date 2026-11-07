import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import 'support/device_inputs.dart';

const int _longestSequence = 8;

void main() {
  test('test_fake_device_repository_new_property_keeps_every_seeded_device_in_'
      'order', () {
    final Random random = seededRandom(64101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Device> seeds = randomDeviceSeeds(random);
      final FakeDeviceRepository repository = buildDeviceRepository(seeds);

      expect(repository.listDevices(), orderedEquals(seeds));
    }
  });

  test(
    'test_fake_device_repository_new_property_refuses_a_current_device_that_'
    'is_not_listed',
    () {
      final Random random = seededRandom(64102);

      for (int i = 0; i < propertyIterations; i += 1) {
        final List<Device> seeds = randomDeviceSeeds(random);
        final DeviceId missing = DeviceId('missing-${randomText(random)}');

        expect(
          () => FakeDeviceRepository(
            devices: seeds,
            currentDeviceId: missing,
            peerAddressProblem: null,
            gitlessFolderPaths: const <String>{},
          ),
          throwsA(isA<RecordNotFound>()),
        );
      }
    },
  );

  test(
    'test_fake_device_repository_new_property_later_changes_to_the_seeds_do_'
    'not_leak',
    () {
      final Random random = seededRandom(64103);

      for (int i = 0; i < propertyIterations; i += 1) {
        final List<Device> seeds = randomDeviceSeeds(random);
        final List<String> seededIds = describeDeviceIds(seeds);
        final FakeDeviceRepository repository = buildDeviceRepository(seeds);

        seeds.add(
          randomDeviceWithId(random, const DeviceId('late'), isRevoked: false),
        );
        seeds.removeAt(0);

        expect(describeDeviceIds(repository.listDevices()), seededIds);
      }
    },
  );

  test('test_list_devices_property_is_unmodifiable', () {
    final Random random = seededRandom(64104);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedDevices counted = buildCountedDeviceRepository(random);
      final List<Device> listed = counted.repository.listDevices();

      expect(() => listed.add(listed.first), throwsUnsupportedError);
      expect(listed.length, counted.seeds.length);
    }
  });

  test(
    'test_list_devices_property_every_listed_device_is_found_by_its_id',
    () async {
      final Random random = seededRandom(64105);

      for (int i = 0; i < propertyIterations; i += 1) {
        final CountedDevices counted = buildCountedDeviceRepository(random);
        final int stepCount = random.nextInt(_longestSequence);
        for (int step = 0; step < stepCount; step += 1) {
          await changeRandomDeviceValidly(random, counted.repository);
        }

        for (final Device listed in counted.repository.listDevices()) {
          expect(counted.repository.findDevice(listed.id), same(listed));
        }
      }
    },
  );

  test(
    'test_list_devices_property_changes_never_add_or_drop_a_device',
    () async {
      final Random random = seededRandom(64106);

      for (int i = 0; i < propertyIterations; i += 1) {
        final CountedDevices counted = buildCountedDeviceRepository(random);
        final int stepCount = random.nextInt(_longestSequence);
        for (int step = 0; step < stepCount; step += 1) {
          await changeRandomDeviceValidly(random, counted.repository);
        }

        expect(
          describeDeviceIds(counted.repository.listDevices()),
          describeDeviceIds(counted.seeds),
        );
      }
    },
  );

  test('test_find_device_property_finds_the_device_with_that_id', () {
    final Random random = seededRandom(64107);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedDevices counted = buildCountedDeviceRepository(random);
      final Device chosen = pickOne(random, counted.seeds);

      expect(counted.repository.findDevice(chosen.id), same(chosen));
    }
  });

  test('test_find_device_property_unknown_ids_name_the_missing_id', () {
    final Random random = seededRandom(64108);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedDevices counted = buildCountedDeviceRepository(random);
      final String identifier = 'unknown ${randomText(random)}';

      expect(
        () => counted.repository.findDevice(DeviceId(identifier)),
        throwsA(
          isA<RecordNotFound>()
              .having((RecordNotFound e) => e.kind, 'kind', 'device')
              .having((RecordNotFound e) => e.identifier, 'id', identifier),
        ),
      );
    }
  });

  test(
    'test_find_device_property_sees_the_newest_version_after_a_change',
    () async {
      final Random random = seededRandom(64109);

      for (int i = 0; i < propertyIterations; i += 1) {
        final CountedDevices counted = buildCountedDeviceRepository(random);
        final Device chosen = pickOne(random, counted.seeds);
        final List<WorkspaceId> outside = <WorkspaceId>[
          for (final WorkspaceId workspaceId in sampleDeviceWorkspaceIds)
            if (!chosen.workspaces.contains(workspaceId)) workspaceId,
        ];
        final bool isThisDevice = chosen.id == deviceTestThisDevice;
        if (chosen.revoked || outside.isEmpty || isThisDevice) {
          continue;
        }
        final WorkspaceId joined = pickOne(random, outside);
        counted.repository.grantWorkspaceToCurrentDevice(joined);

        final Device changed = await counted.repository.addDeviceToWorkspace(
          chosen.id,
          joined,
        );

        expect(counted.repository.findDevice(chosen.id), same(changed));
      }
    },
  );

  test('test_current_device_property_is_the_device_named_at_construction', () {
    final Random random = seededRandom(64110);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Device> seeds = randomDeviceSeeds(random);
      final Device chosen = pickOne(random, seeds);
      final FakeDeviceRepository repository = FakeDeviceRepository(
        devices: seeds,
        currentDeviceId: chosen.id,
        peerAddressProblem: null,
        gitlessFolderPaths: const <String>{},
      );

      expect(repository.currentDevice(), same(chosen));
    }
  });

  test(
    'test_current_device_property_follows_changes_to_this_device',
    () async {
      final Random random = seededRandom(64111);

      for (int i = 0; i < propertyIterations; i += 1) {
        final CountedDevices counted = buildCountedDeviceRepository(random);
        final int stepCount = random.nextInt(_longestSequence);
        for (int step = 0; step < stepCount; step += 1) {
          await changeRandomDeviceValidly(random, counted.repository);
        }

        expect(
          counted.repository.currentDevice(),
          same(counted.repository.findDevice(deviceTestThisDevice)),
        );
      }
    },
  );

  test('test_current_device_property_this_device_is_never_revoked', () async {
    final Random random = seededRandom(64112);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedDevices counted = buildCountedDeviceRepository(random);
      final int stepCount = random.nextInt(_longestSequence);
      for (int step = 0; step < stepCount; step += 1) {
        await changeRandomDeviceValidly(random, counted.repository);
      }

      await expectLater(
        counted.repository.revokeDevice(deviceTestThisDevice),
        throwsStateError,
      );
      expect(counted.repository.currentDevice().revoked, isFalse);
    }
  });
}
