import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/background/xdg_autostart.dart';
import 'package:agent_orchestration/background/xdg_autostart_login_item.dart';

import '../support/random_inputs.dart';
import 'support/autostart_expectations.dart';
import 'support/autostart_folders.dart';
import 'support/hostile_paths.dart';

const int _iterations = 30;
const int _largestChangeCount = 6;
const List<String> _neighbourEntryNames = <String>[
  'dev.orchestration.agent_orchestration.desktop.bak',
  'dev.orchestration.agent_orchestration',
  'other-app.desktop',
  'agent_orchestration.desktop',
  '.dev.orchestration.agent_orchestration.desktop',
];

Map<String, String> _writeRandomNeighbours(
  Random random,
  String autostartFolder,
) {
  final Map<String, String> neighbourTexts = <String, String>{};
  for (final String name in _neighbourEntryNames) {
    if (random.nextBool()) {
      neighbourTexts['$autostartFolder/$name'] = randomText(random);
    }
  }
  for (final MapEntry<String, String> neighbour in neighbourTexts.entries) {
    final File neighbourFile = File(neighbour.key);
    neighbourFile.createSync(recursive: true);
    neighbourFile.writeAsStringSync(neighbour.value);
  }
  return neighbourTexts;
}

void main() {
  test(
    'test_xdg_autostart_login_item_register_property_last_change_wins',
    () async {
      final Random random = seededRandom(48704);

      for (int i = 0; i < _iterations; i += 1) {
        final Directory root = createTemporaryFolder();
        final Map<String, String> environment = randomEnvironmentInside(
          random,
          root,
        );
        final File entry = File(locateAutostartEntry(environment));
        final int changeCount = 1 + random.nextInt(_largestChangeCount);
        String? lastRegisteredPath;

        for (int change = 0; change < changeCount; change += 1) {
          final XdgAutostartLoginItem loginItem = XdgAutostartLoginItem(
            environment: environment,
            executablePath: randomHostileAbsolutePath(random),
          );
          if (random.nextBool()) {
            await loginItem.register();
            lastRegisteredPath = loginItem.executablePath;
          } else {
            await loginItem.unregister();
            lastRegisteredPath = null;
          }

          expect(entry.existsSync(), lastRegisteredPath != null);
          if (lastRegisteredPath != null) {
            expect(
              entry.readAsStringSync(),
              renderAutostartEntry(lastRegisteredPath),
            );
          }
        }
      }
    },
  );

  test(
    'test_xdg_autostart_login_item_unregister_property_spares_other_entries',
    () async {
      final Random random = seededRandom(48705);

      for (int i = 0; i < _iterations; i += 1) {
        final Directory root = createTemporaryFolder();
        final Map<String, String> environment = randomEnvironmentInside(
          random,
          root,
        );
        final String entryPath = locateAutostartEntry(environment);
        final Map<String, String> neighbourTexts = _writeRandomNeighbours(
          random,
          File(entryPath).parent.path,
        );
        final XdgAutostartLoginItem loginItem = XdgAutostartLoginItem(
          environment: environment,
          executablePath: randomHostileAbsolutePath(random),
        );

        if (random.nextBool()) {
          await loginItem.register();
        }
        await loginItem.unregister();

        expect(File(entryPath).existsSync(), isFalse);
        for (final MapEntry<String, String> neighbour
            in neighbourTexts.entries) {
          expect(File(neighbour.key).readAsStringSync(), neighbour.value);
        }
      }
    },
  );

  test(
    'test_xdg_autostart_login_item_unregister_property_no_entry_behind_file',
    () async {
      final Random random = seededRandom(48706);

      for (int i = 0; i < _iterations; i += 1) {
        final Directory root = createTemporaryFolder();
        final Map<String, String> environment = randomEnvironmentInside(
          random,
          root,
        );
        final String entryPath = locateAutostartEntry(environment);
        final List<String> folders = listFoldersBetween(
          root: root,
          entryPath: entryPath,
        );
        blockWithFile(pickOne(random, folders));
        final XdgAutostartLoginItem loginItem = XdgAutostartLoginItem(
          environment: environment,
          executablePath: randomHostileAbsolutePath(random),
        );

        await loginItem.unregister();

        expect(File(entryPath).existsSync(), isFalse);
      }
    },
  );
}
