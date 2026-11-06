import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/background/login_item.dart';
import 'package:agent_orchestration/background/xdg_autostart.dart';
import 'package:agent_orchestration/background/xdg_autostart_login_item.dart';

import '../support/random_inputs.dart';
import 'support/autostart_expectations.dart';
import 'support/autostart_folders.dart';
import 'support/hostile_paths.dart';

const int _iterations = 30;
const String _partSeparator = ': ';

bool _namesEntryOrOneOfItsFolders(String message, String entryPath) {
  String path = entryPath;
  while (path.length > 1) {
    if (message.contains('$_partSeparator$path$_partSeparator')) {
      return true;
    }
    path = File(path).parent.path;
  }
  return false;
}

bool _endsWithReason(String message) {
  final String reason = message.split(_partSeparator).last;
  return reason.trim().isNotEmpty;
}

Matcher _throwsExplainedFileProblem({
  required String problem,
  required String entryPath,
}) {
  return throwsA(
    isA<StateError>().having(
      (StateError error) => error.message,
      'message',
      allOf(
        startsWith('$problem$_partSeparator'),
        isNot(contains('${_partSeparator}null')),
        predicate<String>(
          (String message) => _namesEntryOrOneOfItsFolders(message, entryPath),
          'names the entry or one of its folders',
        ),
        predicate<String>(_endsWithReason, 'ends with a reason'),
      ),
    ),
  );
}

Future<String> _readOperatingSystemReason(Future<void> operation) async {
  try {
    await operation;
  } on FileSystemException catch (failure) {
    final OSError? operatingSystemError = failure.osError;
    if (operatingSystemError == null) {
      fail('the file system gave no operating system reason');
    }
    return operatingSystemError.message;
  }
  fail('the operation did not fail');
}

XdgAutostartLoginItem _buildLoginItem(
  Random random,
  Map<String, String> environment,
) {
  return XdgAutostartLoginItem(
    environment: environment,
    executablePath: randomHostileAbsolutePath(random),
  );
}

void main() {
  test(
    'test_describe_file_problem_property_register_names_path_and_reason',
    () async {
      final Random random = seededRandom(48701);

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
        if (random.nextBool()) {
          blockWithFile(pickOne(random, folders));
        } else {
          blockWithFolder(entryPath);
        }

        await expectLater(
          _buildLoginItem(random, environment).register(),
          _throwsExplainedFileProblem(
            problem: startAtLoginProblem,
            entryPath: entryPath,
          ),
        );
      }
    },
  );

  test(
    'test_describe_file_problem_property_unregister_names_path_and_reason',
    () async {
      final Random random = seededRandom(48702);

      for (int i = 0; i < _iterations; i += 1) {
        final Directory root = createTemporaryFolder();
        final Map<String, String> environment = randomEnvironmentInside(
          random,
          root,
        );
        final String entryPath = locateAutostartEntry(environment);
        blockWithFolder(entryPath);

        await expectLater(
          _buildLoginItem(random, environment).unregister(),
          _throwsExplainedFileProblem(
            problem: stopStartingAtLoginProblem,
            entryPath: entryPath,
          ),
        );
      }
    },
  );

  test(
    'test_describe_file_problem_property_reason_is_the_system_reason',
    () async {
      final Random random = seededRandom(48703);

      for (int i = 0; i < _iterations; i += 1) {
        final Directory root = createTemporaryFolder();
        final Map<String, String> environment = randomEnvironmentInside(
          random,
          root,
        );
        final String entryPath = locateAutostartEntry(environment);
        blockWithFolder(entryPath);
        final String systemReason = await _readOperatingSystemReason(
          File(entryPath).delete(),
        );

        await expectLater(
          _buildLoginItem(random, environment).unregister(),
          throwsA(
            isA<StateError>().having(
              (StateError error) => error.message,
              'message',
              endsWith('$_partSeparator$systemReason'),
            ),
          ),
        );
      }
    },
  );
}
