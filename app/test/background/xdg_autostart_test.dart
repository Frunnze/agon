import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/background/xdg_autostart.dart';
import 'package:agent_orchestration/product_name.dart';

import '../support/desktop_entry_reading.dart';
import '../support/random_inputs.dart';

const String _entryEnding =
    '/autostart/dev.orchestration.agent_orchestration.desktop';
const List<String> _pathCharacters = <String>[
  'a',
  'Z',
  '7',
  '_',
  '-',
  '.',
  ' ',
  '"',
  "'",
  r'$',
  '`',
  r'\',
  '%',
  '=',
  ';',
  '#',
  'é',
  '火',
  '/',
];

String _randomAbsolutePath(Random random) {
  final StringBuffer path = StringBuffer('/');
  final int length = 1 + random.nextInt(30);
  for (int i = 0; i < length; i += 1) {
    path.write(pickOne(random, _pathCharacters));
  }
  return path.toString();
}

bool _hasControlCharacter(String text) {
  for (final int codeUnit in text.codeUnits) {
    if (codeUnit < 0x20 || codeUnit == 0x7f) {
      return true;
    }
  }
  return false;
}

Map<String, String> _randomEnvironmentWithout(
  Random random, {
  required Set<String> names,
}) {
  final Map<String, String> environment = <String, String>{};
  final int count = random.nextInt(4);
  for (int i = 0; i < count; i += 1) {
    final String name = 'VARIABLE_${random.nextInt(1000)}';
    if (!names.contains(name)) {
      environment[name] = randomText(random);
    }
  }
  return environment;
}

void main() {
  test('test_render_autostart_entry_property_exec_round_trips_the_path', () {
    final Random random = seededRandom(12201);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String executablePath = _randomAbsolutePath(random);
      final String entryText = renderAutostartEntry(executablePath);

      final String execValue = readDesktopEntryValue(entryText, 'Exec');
      expect(parseDesktopEntryExec(execValue), <String>[executablePath]);
    }
  });

  test('test_render_autostart_entry_property_is_an_application_entry', () {
    final Random random = seededRandom(12202);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String entryText = renderAutostartEntry(
        _randomAbsolutePath(random),
      );
      final List<String> lines = entryText.split('\n');

      expect(lines.first, '[Desktop Entry]');
      expect(entryText.endsWith('\n'), isTrue);
      expect(readDesktopEntryValue(entryText, 'Type'), 'Application');
      expect(readDesktopEntryValue(entryText, 'Name'), productName);
      expect(lines.where((String line) => line.startsWith('Exec=')).length, 1);
    }
  });

  test('test_render_autostart_entry_property_pins_the_design_text', () {
    expect(
      renderAutostartEntry('/opt/agents/agent_orchestration'),
      '[Desktop Entry]\n'
      'Type=Application\n'
      'Name=Agon\n'
      'Exec="/opt/agents/agent_orchestration"\n',
    );
    expect(
      readDesktopEntryValue(renderAutostartEntry(r'/a b/$c"%d\e'), 'Exec'),
      r'"/a b/\\$c\\"%%d\\\\e"',
    );
  });

  test('test_render_autostart_entry_property_refuses_unusable_paths', () {
    final Random random = seededRandom(12203);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String executablePath = randomText(random);
      final bool isUsable =
          executablePath.startsWith('/') &&
          !_hasControlCharacter(executablePath);

      if (!isUsable) {
        expect(
          () => renderAutostartEntry(executablePath),
          throwsArgumentError,
        );
        continue;
      }
      final String execValue = readDesktopEntryValue(
        renderAutostartEntry(executablePath),
        'Exec',
      );
      expect(parseDesktopEntryExec(execValue), <String>[executablePath]);
    }
    expect(() => renderAutostartEntry('/a\nb'), throwsArgumentError);
    expect(() => renderAutostartEntry('relative/app'), throwsArgumentError);
  });

  test(
    'test_locate_autostart_entry_property_prefers_an_absolute_config_home',
    () {
      final Random random = seededRandom(12204);
      for (int i = 0; i < propertyIterations; i += 1) {
        final String configurationHome = _randomAbsolutePath(random);
        final Map<String, String> environment = <String, String>{
          'XDG_CONFIG_HOME': configurationHome,
          if (random.nextBool()) 'HOME': _randomAbsolutePath(random),
        };

        expect(
          locateAutostartEntry(environment),
          '$configurationHome$_entryEnding',
        );
      }
    },
  );

  test('test_locate_autostart_entry_property_falls_back_to_home_config', () {
    final Random random = seededRandom(12205);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String home = _randomAbsolutePath(random);
      final Map<String, String> environment = <String, String>{'HOME': home};
      final int configurationHomeShape = random.nextInt(3);
      if (configurationHomeShape == 1) {
        environment['XDG_CONFIG_HOME'] = '';
      }
      if (configurationHomeShape == 2) {
        environment['XDG_CONFIG_HOME'] = 'relative/${randomText(random)}';
      }

      expect(locateAutostartEntry(environment), '$home/.config$_entryEnding');
    }
  });

  test('test_locate_autostart_entry_property_refuses_without_a_home', () {
    final Random random = seededRandom(12206);
    const Set<String> folderNames = <String>{'HOME', 'XDG_CONFIG_HOME'};
    for (int i = 0; i < propertyIterations; i += 1) {
      final Map<String, String> environment = _randomEnvironmentWithout(
        random,
        names: folderNames,
      );
      if (random.nextBool()) {
        environment['HOME'] = random.nextBool() ? '' : 'home/user';
      }
      if (random.nextBool()) {
        environment['XDG_CONFIG_HOME'] = random.nextBool() ? '' : 'config';
      }

      expect(
        () => locateAutostartEntry(environment),
        throwsA(isA<StateError>()),
      );
    }
  });
}
