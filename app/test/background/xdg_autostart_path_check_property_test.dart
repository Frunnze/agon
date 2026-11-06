import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/background/xdg_autostart.dart';
import 'package:agent_orchestration/background/xdg_autostart_login_item.dart';

import '../support/random_inputs.dart';
import 'support/autostart_expectations.dart';
import 'support/hostile_paths.dart';

const String _healthyExecutablePath = '/opt/agents/agent_orchestration';
const String _newline = '\n';
const int _largestUnicodePieceCount = 20;
const List<String> _unicodePathPieces = <String>[
  'a',
  'ß',
  'é',
  'e\u0301',
  '火',
  '\u{1f600}',
  '\u{1f469}\u200d\u{1f4bb}',
  '\u202e',
  '\u200b',
  '\u2028',
  '\u2029',
  '\u00a0',
  '\ufeff',
];
const List<int> _refusedEdgeCodeUnits = <int>[0x00, 0x1f, 0x7f];
const List<int> _keptEdgeCodeUnits = <int>[0x20, 0x21, 0x7e];

String _randomUnicodePath(Random random) {
  final StringBuffer path = StringBuffer('/');
  final int pieceCount = random.nextInt(_largestUnicodePieceCount);
  for (int i = 0; i < pieceCount; i += 1) {
    path.write(pickOne(random, _unicodePathPieces));
  }
  return path.toString();
}

bool _hasControlCodeUnit(String text) {
  final List<int> controls = controlCodeUnits();
  for (final int codeUnit in text.codeUnits) {
    if (controls.contains(codeUnit)) {
      return true;
    }
  }
  return false;
}

String _randomControlCharacter(Random random) {
  return String.fromCharCode(pickOne(random, controlCodeUnits()));
}

String _randomCandidatePath(Random random) {
  String candidate = randomRelativePath(random);
  if (random.nextBool()) {
    candidate = randomHostileAbsolutePath(random);
  }
  if (random.nextInt(3) == 0) {
    final String control = _randomControlCharacter(random);
    candidate = insertAtRandomPlace(random, candidate, control);
  }
  return candidate;
}

String _randomRefusedPath(Random random) {
  final String candidate = _randomCandidatePath(random);
  final bool isUsable =
      candidate.startsWith('/') && !_hasControlCodeUnit(candidate);
  if (isUsable) {
    return insertAtRandomPlace(random, candidate, _newline);
  }
  return candidate;
}

void main() {
  test(
    'test_has_control_character_property_every_control_unit_is_refused',
    () {
      final Random random = seededRandom(48501);

      for (final int codeUnit in controlCodeUnits()) {
        for (int i = 0; i < widgetPropertyIterations; i += 1) {
          final String executablePath = insertAtRandomPlace(
            random,
            randomHostileAbsolutePath(random),
            String.fromCharCode(codeUnit),
          );

          expect(
            () => renderAutostartEntry(executablePath),
            throwsArgumentErrorAbout(executablePath),
            reason: 'code unit $codeUnit',
          );
        }
      }
    },
  );

  test('test_has_control_character_property_unicode_paths_are_kept', () {
    final Random random = seededRandom(48502);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String executablePath = _randomUnicodePath(random);

      expect(readExecArguments(executablePath), <String>[executablePath]);
    }
  });

  test('test_has_control_character_property_edges_of_the_control_range', () {
    final Random random = seededRandom(48503);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String path = randomHostileAbsolutePath(random);
      final String refusedPath = insertAtRandomPlace(
        random,
        path,
        String.fromCharCode(pickOne(random, _refusedEdgeCodeUnits)),
      );
      final String keptPath = insertAtRandomPlace(
        random,
        path,
        String.fromCharCode(pickOne(random, _keptEdgeCodeUnits)),
      );

      expect(() => renderAutostartEntry(refusedPath), throwsArgumentError);
      expect(readExecArguments(keptPath), <String>[keptPath]);
    }
  });

  test('test_check_executable_path_property_accepts_absolute_printable', () {
    final Random random = seededRandom(48504);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String candidate = _randomCandidatePath(random);
      final bool isUsable =
          candidate.startsWith('/') && !_hasControlCodeUnit(candidate);

      if (isUsable) {
        expect(readExecArguments(candidate), <String>[candidate]);
        continue;
      }
      expect(
        () => renderAutostartEntry(candidate),
        throwsArgumentErrorAbout(candidate),
      );
    }
  });

  test(
    'test_check_executable_path_property_refusal_keeps_the_previous_entry',
    () async {
      final Random random = seededRandom(48505);
      final Directory root = createTemporaryFolder();
      final Map<String, String> environment = <String, String>{
        'XDG_CONFIG_HOME': root.path,
      };
      final File entry = File(locateAutostartEntry(environment));
      final XdgAutostartLoginItem healthyLoginItem = XdgAutostartLoginItem(
        environment: environment,
        executablePath: _healthyExecutablePath,
      );

      for (int i = 0; i < propertyIterations; i += 1) {
        final bool hasPreviousEntry = random.nextBool();
        await healthyLoginItem.unregister();
        if (hasPreviousEntry) {
          await healthyLoginItem.register();
        }
        final String refusedPath = _randomRefusedPath(random);
        final XdgAutostartLoginItem refusedLoginItem = XdgAutostartLoginItem(
          environment: environment,
          executablePath: refusedPath,
        );

        await expectLater(
          refusedLoginItem.register(),
          throwsArgumentErrorAbout(refusedPath),
        );

        expect(entry.existsSync(), hasPreviousEntry);
        if (hasPreviousEntry) {
          expect(
            entry.readAsStringSync(),
            renderAutostartEntry(_healthyExecutablePath),
          );
        }
      }
    },
  );

  test('test_check_executable_path_property_names_the_argument_and_value', () {
    final Random random = seededRandom(48506);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String relativePath = randomRelativePath(random);
      final String controlPath = insertAtRandomPlace(
        random,
        randomHostileAbsolutePath(random),
        _randomControlCharacter(random),
      );

      expect(
        () => renderAutostartEntry(relativePath),
        throwsArgumentErrorAbout(relativePath),
      );
      expect(
        () => renderAutostartEntry(controlPath),
        throwsArgumentErrorAbout(controlPath),
      );
    }
  });
}
