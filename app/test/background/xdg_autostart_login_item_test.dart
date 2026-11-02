import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/background/login_item.dart';
import 'package:agent_orchestration/background/xdg_autostart.dart';
import 'package:agent_orchestration/background/xdg_autostart_login_item.dart';

import '../support/random_inputs.dart';

const int _iterations = 30;
const String _executablePath = '/opt/agents/agent_orchestration';

Directory _createTemporaryFolder() {
  final Directory folder = Directory.systemTemp.createTempSync('autostart_');
  addTearDown(() => folder.deleteSync(recursive: true));
  return folder;
}

String _randomConfigurationHome(Random random, Directory root) {
  final StringBuffer path = StringBuffer(root.path);
  final int depth = random.nextInt(3);
  for (int i = 0; i < depth; i += 1) {
    path.write('/folder ${random.nextInt(100)}');
  }
  return path.toString();
}

Matcher _throwsProblemStartingWith(String problem) {
  return throwsA(
    isA<StateError>().having(
      (StateError error) => error.message,
      'message',
      startsWith(problem),
    ),
  );
}

void main() {
  test('test_register_property_writes_the_rendered_entry', () async {
    final Random random = seededRandom(12301);
    for (int i = 0; i < _iterations; i += 1) {
      final Directory root = _createTemporaryFolder();
      final Map<String, String> environment = <String, String>{
        'XDG_CONFIG_HOME': _randomConfigurationHome(random, root),
      };
      final XdgAutostartLoginItem loginItem = XdgAutostartLoginItem(
        environment: environment,
        executablePath: _executablePath,
      );
      final int registerCount = 1 + random.nextInt(3);

      for (int attempt = 0; attempt < registerCount; attempt += 1) {
        await loginItem.register();
      }

      final File entry = File(locateAutostartEntry(environment));
      expect(entry.readAsStringSync(), renderAutostartEntry(_executablePath));
    }
  });

  test('test_unregister_property_removes_the_entry_every_time', () async {
    final Random random = seededRandom(12302);
    for (int i = 0; i < _iterations; i += 1) {
      final Directory root = _createTemporaryFolder();
      final Map<String, String> environment = <String, String>{
        'HOME': _randomConfigurationHome(random, root),
      };
      final XdgAutostartLoginItem loginItem = XdgAutostartLoginItem(
        environment: environment,
        executablePath: _executablePath,
      );
      final File entry = File(locateAutostartEntry(environment));
      final bool isRegisteredFirst = random.nextBool();
      final int unregisterCount = 1 + random.nextInt(3);

      if (isRegisteredFirst) {
        await loginItem.register();
        expect(entry.existsSync(), isTrue);
      }
      for (int attempt = 0; attempt < unregisterCount; attempt += 1) {
        await loginItem.unregister();
      }

      expect(entry.existsSync(), isFalse);
      expect(entry.parent.existsSync(), isRegisteredFirst);
    }
  });

  test('test_register_property_unwritable_folder_fails_visibly', () async {
    final Directory root = _createTemporaryFolder();
    final File blockingFile = File('${root.path}/not-a-folder')
      ..writeAsStringSync('');
    final XdgAutostartLoginItem loginItem = XdgAutostartLoginItem(
      environment: <String, String>{'XDG_CONFIG_HOME': blockingFile.path},
      executablePath: _executablePath,
    );

    await expectLater(
      loginItem.register(),
      _throwsProblemStartingWith(startAtLoginProblem),
    );
  });

  test('test_unregister_property_undeletable_entry_fails_visibly', () async {
    final Directory root = _createTemporaryFolder();
    final Map<String, String> environment = <String, String>{
      'XDG_CONFIG_HOME': root.path,
    };
    Directory(locateAutostartEntry(environment)).createSync(recursive: true);
    final XdgAutostartLoginItem loginItem = XdgAutostartLoginItem(
      environment: environment,
      executablePath: _executablePath,
    );

    await expectLater(
      loginItem.unregister(),
      _throwsProblemStartingWith(stopStartingAtLoginProblem),
    );
  });

  test('test_register_property_unusable_inputs_fail_before_writing', () async {
    final Random random = seededRandom(12303);
    for (int i = 0; i < _iterations; i += 1) {
      final Directory root = _createTemporaryFolder();
      final XdgAutostartLoginItem withoutHome = XdgAutostartLoginItem(
        environment: <String, String>{'HOME': randomText(random).trim()},
        executablePath: _executablePath,
      );
      final XdgAutostartLoginItem relativeExecutable = XdgAutostartLoginItem(
        environment: <String, String>{'XDG_CONFIG_HOME': root.path},
        executablePath: 'relative/${randomText(random)}',
      );

      if (!(withoutHome.environment['HOME'] ?? '').startsWith('/')) {
        await expectLater(withoutHome.register(), throwsStateError);
      }
      await expectLater(relativeExecutable.register(), throwsArgumentError);
      expect(root.listSync(), isEmpty);
    }
  });
}
