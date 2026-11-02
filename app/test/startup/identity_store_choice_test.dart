import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/node/node_start_configuration.dart';
import 'package:agent_orchestration/startup/app_build_mode.dart';
import 'package:agent_orchestration/startup/identity_store_choice.dart';

import '../support/memory_secret_store.dart';
import '../support/random_inputs.dart';

const List<String> _phoneSystems = <String>['android', 'ios'];
const List<String> _desktopSystems = <String>['macos', 'windows', 'linux'];
final RegExp _identityKeyShape = RegExp(r'^[0-9a-f]{64}$');

void main() {
  test(
    'test_read_or_create_identity_key_property_made_once_and_kept',
    () async {
      final Random random = seededRandom(10061);
      for (int i = 0; i < propertyIterations; i += 1) {
        final MemorySecretStore store = MemorySecretStore();
        final String first = await readOrCreateIdentityKey(
          secrets: store,
          random: random,
        );
        final String second = await readOrCreateIdentityKey(
          secrets: store,
          random: random,
        );

        expect(first, matches(_identityKeyShape));
        expect(second, first);
        expect(store.writeCount, 1);
      }
    },
  );

  test(
    'test_read_or_create_identity_key_property_damaged_key_fails',
    () async {
      final Random random = seededRandom(10062);
      for (int i = 0; i < propertyIterations; i += 1) {
        final MemorySecretStore store = MemorySecretStore();
        store.secrets[identityKeySecretName] = 'damaged ${randomText(random)}';

        await expectLater(
          readOrCreateIdentityKey(secrets: store, random: random),
          throwsFormatException,
        );
        expect(store.writeCount, 0);
      }
    },
  );

  test(
    'test_choose_identity_store_property_keychain_only_for_released_computers',
    () async {
      final Random random = seededRandom(10063);
      for (int i = 0; i < propertyIterations; i += 1) {
        final MemorySecretStore store = MemorySecretStore();
        final String system = pickOne(random, <String>[
          ..._phoneSystems,
          ..._desktopSystems,
        ]);
        final AppBuildMode buildMode = pickOne(random, AppBuildMode.values);

        final IdentityStoreSettings choice = await chooseIdentityStore(
          operatingSystem: system,
          buildMode: buildMode,
          secrets: store,
          random: random,
        );

        final String reason = '$system $buildMode';
        if (_phoneSystems.contains(system)) {
          expect(choice, isA<EncryptedFileIdentityStore>(), reason: reason);
          expect(
            (choice as EncryptedFileIdentityStore).key,
            store.secrets[identityKeySecretName],
          );
        } else if (buildMode == AppBuildMode.debug) {
          expect(choice, isA<FileIdentityStore>(), reason: reason);
          expect(store.secrets, isEmpty);
        } else {
          expect(choice, isA<KeychainIdentityStore>(), reason: reason);
          expect(store.secrets, isEmpty);
        }
      }
    },
  );
}
