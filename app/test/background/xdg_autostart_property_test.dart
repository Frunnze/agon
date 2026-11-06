import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/background/xdg_autostart.dart';

import '../support/random_inputs.dart';
import 'support/autostart_expectations.dart';
import 'support/hostile_paths.dart';

const String _configurationHomeVariable = 'XDG_CONFIG_HOME';
const String _homeVariable = 'HOME';
const String _entryEnding =
    '/autostart/dev.orchestration.agent_orchestration.desktop';
const String _fallbackHome = '/fallback home';
const int _largestNoiseCount = 5;
const List<String> _nearMissVariableNames = <String>[
  'xdg_config_home',
  'XDG_CONFIG_HOME ',
  ' XDG_CONFIG_HOME',
  'XDG_CONFIG_DIRS',
  'XDG_DATA_HOME',
  'home',
  'HOME_DIR',
  ' HOME',
  'USERPROFILE',
];

enum _FolderShape { absent, empty, relative, absolute }

String? _randomFolderOfShape(Random random, _FolderShape shape) {
  switch (shape) {
    case _FolderShape.absent:
      return null;
    case _FolderShape.empty:
      return '';
    case _FolderShape.relative:
      return randomRelativePath(random);
    case _FolderShape.absolute:
      return randomHostileAbsolutePath(random);
  }
}

String? _expectConfigurationHome({
  required String? configurationHome,
  required String? home,
}) {
  if (configurationHome != null && configurationHome.startsWith('/')) {
    return configurationHome;
  }
  if (home != null && home.startsWith('/')) {
    return '$home/.config';
  }
  return null;
}

Map<String, String> _withRandomNoise(
  Random random,
  Map<String, String> environment,
) {
  final Map<String, String> noisyEnvironment = Map<String, String>.of(
    environment,
  );
  final int noiseCount = random.nextInt(_largestNoiseCount);
  for (int i = 0; i < noiseCount; i += 1) {
    final String name = pickOne(random, _nearMissVariableNames);
    noisyEnvironment[name] = randomHostileAbsolutePath(random);
  }
  return noisyEnvironment;
}

void main() {
  test('test_is_absolute_property_one_rule_for_every_path_it_judges', () {
    final Random random = seededRandom(48401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String candidate = random.nextBool()
          ? randomHostileAbsolutePath(random)
          : randomRelativePath(random);
      final bool isAbsolute = candidate.startsWith('/');
      final String locatedWithCandidate = locateAutostartEntry(
        <String, String>{
          _configurationHomeVariable: candidate,
          _homeVariable: _fallbackHome,
        },
      );

      if (isAbsolute) {
        expect(readExecArguments(candidate), <String>[candidate]);
        expect(locatedWithCandidate, '$candidate$_entryEnding');
        expect(
          locateAutostartEntry(<String, String>{_homeVariable: candidate}),
          '$candidate/.config$_entryEnding',
        );
        continue;
      }
      expect(() => renderAutostartEntry(candidate), throwsArgumentError);
      expect(locatedWithCandidate, '$_fallbackHome/.config$_entryEnding');
      expect(
        () => locateAutostartEntry(<String, String>{_homeVariable: candidate}),
        throwsStateError,
      );
    }
  });

  test('test_is_absolute_property_relative_executables_name_the_path', () {
    final Random random = seededRandom(48402);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String relativePath = randomRelativePath(random);

      expect(
        () => renderAutostartEntry(relativePath),
        throwsArgumentErrorAbout(relativePath),
      );
    }
  });

  test('test_is_absolute_property_located_entries_are_always_absolute', () {
    final Random random = seededRandom(48403);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Map<String, String> environment = <String, String>{};
      final String? configurationHome = _randomFolderOfShape(
        random,
        pickOne(random, _FolderShape.values),
      );
      final String? home = _randomFolderOfShape(
        random,
        pickOne(random, _FolderShape.values),
      );
      if (configurationHome != null) {
        environment[_configurationHomeVariable] = configurationHome;
      }
      if (home != null) {
        environment[_homeVariable] = home;
      }
      final String? expectedHome = _expectConfigurationHome(
        configurationHome: configurationHome,
        home: home,
      );

      if (expectedHome == null) {
        expect(() => locateAutostartEntry(environment), throwsStateError);
        continue;
      }
      expect(locateAutostartEntry(environment), startsWith('/'));
    }
  });

  test(
    'test_find_configuration_home_property_follows_the_xdg_decision_table',
    () {
      final Random random = seededRandom(48404);

      for (final _FolderShape configurationShape in _FolderShape.values) {
        for (final _FolderShape homeShape in _FolderShape.values) {
          for (int i = 0; i < widgetPropertyIterations; i += 1) {
            final String? configurationHome = _randomFolderOfShape(
              random,
              configurationShape,
            );
            final String? home = _randomFolderOfShape(random, homeShape);
            final Map<String, String> environment = <String, String>{
              _configurationHomeVariable: ?configurationHome,
              _homeVariable: ?home,
            };
            final String? expectedHome = _expectConfigurationHome(
              configurationHome: configurationHome,
              home: home,
            );

            if (expectedHome == null) {
              expect(
                () => locateAutostartEntry(environment),
                throwsStateError,
              );
              continue;
            }
            expect(
              locateAutostartEntry(environment),
              '$expectedHome$_entryEnding',
            );
          }
        }
      }
    },
  );

  test(
    'test_find_configuration_home_property_unrelated_variables_never_matter',
    () {
      final Random random = seededRandom(48405);

      for (int i = 0; i < propertyIterations; i += 1) {
        final Map<String, String> environment = <String, String>{
          _homeVariable: randomHostileAbsolutePath(random),
        };
        if (random.nextBool()) {
          environment[_configurationHomeVariable] = randomHostileAbsolutePath(
            random,
          );
        }
        final Map<String, String> noisyEnvironment = _withRandomNoise(
          random,
          environment,
        );

        expect(
          locateAutostartEntry(noisyEnvironment),
          locateAutostartEntry(environment),
        );
      }
    },
  );

  test(
    'test_find_configuration_home_property_reads_without_changing_anything',
    () {
      final Random random = seededRandom(48406);

      for (int i = 0; i < propertyIterations; i += 1) {
        final Map<String, String> environment =
            Map<String, String>.unmodifiable(
              _withRandomNoise(random, <String, String>{
                _homeVariable: randomHostileAbsolutePath(random),
              }),
            );
        final Map<String, String> environmentBefore = Map<String, String>.of(
          environment,
        );

        final String firstEntry = locateAutostartEntry(environment);
        final String secondEntry = locateAutostartEntry(environment);

        expect(secondEntry, firstEntry);
        expect(environment, environmentBefore);
      }
    },
  );
}
