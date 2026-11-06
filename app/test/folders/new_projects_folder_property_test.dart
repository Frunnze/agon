import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/folders/new_projects_folder.dart';

import '../support/random_inputs.dart';

const String _homeVariable = 'HOME';
const String _windowsHomeVariable = 'USERPROFILE';
const String _newProjectsFolderName = 'Agon';
const List<String> _homeFolders = <String>[
  '/Users/sam',
  '/home/kim lee',
  '/Users/zoë/',
  '/root//',
];
const List<String> _blankTexts = <String>['', ' ', '\t', '  \n'];

String _withoutTrailingSeparators(String path) {
  String trimmed = path.trim();
  while (trimmed.length > 1 && trimmed.endsWith(Platform.pathSeparator)) {
    trimmed = trimmed.substring(0, trimmed.length - 1);
  }
  return trimmed;
}

void main() {
  test('test_describe_new_projects_folder_property_agon_inside_home', () {
    final Random random = seededRandom(9931);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String home = pickOne(random, _homeFolders);
      final Map<String, String> environment = <String, String>{
        _homeVariable: home,
      };

      final String folder = describeNewProjectsFolder(environment);

      final String trimmedHome = _withoutTrailingSeparators(home);
      final String expectedFolder =
          '$trimmedHome${Platform.pathSeparator}$_newProjectsFolderName';
      expect(folder, expectedFolder);
      expect(folder.contains(Platform.pathSeparator * 2), isFalse);
    }
  });

  test(
    'test_describe_new_projects_folder_property_home_wins_over_profile',
    () {
      final Random random = seededRandom(9932);
      for (int i = 0; i < propertyIterations; i += 1) {
        final String home = pickOne(random, _homeFolders);
        final String profile = pickOne(random, _homeFolders);
        final Map<String, String> bothVariables = <String, String>{
          _homeVariable: home,
          _windowsHomeVariable: '$profile-other',
        };
        final Map<String, String> profileOnly = <String, String>{
          _homeVariable: pickOne(random, _blankTexts),
          _windowsHomeVariable: profile,
        };

        final String fromHome = describeNewProjectsFolder(bothVariables);
        final String fromProfile = describeNewProjectsFolder(profileOnly);

        expect(fromHome, startsWith(_withoutTrailingSeparators(home)));
        expect(fromProfile, startsWith(_withoutTrailingSeparators(profile)));
      }
    },
  );

  test('test_describe_new_projects_folder_property_no_home_is_refused', () {
    final Random random = seededRandom(9933);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Map<String, String> environment = <String, String>{
        if (random.nextBool()) _homeVariable: pickOne(random, _blankTexts),
        if (random.nextBool())
          _windowsHomeVariable: pickOne(random, _blankTexts),
        'PATH': randomText(random),
      };

      expect(
        () => describeNewProjectsFolder(environment),
        throwsA(isA<StateError>()),
      );
    }
  });

  test('test_make_new_projects_folder_property_makes_the_folder', () async {
    final Random random = seededRandom(9934);
    for (int i = 0; i < _homeFolders.length; i += 1) {
      final Directory home = await Directory.systemTemp.createTemp('home');
      addTearDown(() => home.delete(recursive: true));
      final Map<String, String> environment = <String, String>{
        _homeVariable: home.path,
        if (random.nextBool()) _windowsHomeVariable: randomText(random),
      };

      final String folder = await makeNewProjectsFolder(environment);

      expect(folder, describeNewProjectsFolder(environment));
      expect(Directory(folder).existsSync(), isTrue);
    }
  });

  test('test_make_new_projects_folder_property_repeat_keeps_files', () async {
    final Random random = seededRandom(9935);
    for (int i = 0; i < _homeFolders.length; i += 1) {
      final Directory home = await Directory.systemTemp.createTemp('home');
      addTearDown(() => home.delete(recursive: true));
      final Map<String, String> environment = <String, String>{
        _homeVariable: home.path,
      };
      final String firstFolder = await makeNewProjectsFolder(environment);
      final String keptName = 'kept-${random.nextInt(1000)}';
      final File keptFile = File('$firstFolder/$keptName');
      await keptFile.writeAsString(keptName);

      final String secondFolder = await makeNewProjectsFolder(environment);

      expect(secondFolder, firstFolder);
      expect(await keptFile.readAsString(), keptName);
    }
  });

  test(
    'test_make_new_projects_folder_property_no_home_makes_nothing',
    () async {
      final Random random = seededRandom(9936);
      for (int i = 0; i < propertyIterations; i += 1) {
        final Map<String, String> environment = <String, String>{
          _homeVariable: pickOne(random, _blankTexts),
        };

        await expectLater(
          makeNewProjectsFolder(environment),
          throwsA(isA<StateError>()),
        );
      }
    },
  );
}
