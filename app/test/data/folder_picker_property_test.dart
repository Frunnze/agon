import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/folder_picker.dart';
import 'package:agent_orchestration/folders/new_projects_folder.dart';
import 'package:agent_orchestration/folders/platform_folder_picker.dart';
import 'package:agent_orchestration/folders/runner_folder_picker.dart';

import '../support/fixed_folder_picker.dart';
import '../support/random_inputs.dart';
import '../support/sample_folder_paths.dart';

const MethodChannel _fileSelectorChannel = MethodChannel(
  'plugins.flutter.io/file_selector',
);
const String _newProjectsFolderName = 'Agon';
const int _largestCallCount = 4;
const int _cancelOneIn = 3;
const List<String> _unusualFolderPaths = <String>[
  '/Users/kim lee/My Projects',
  '/Users/zo\u00EB/caf\u00E9/',
  '/tmp/  padded  ',
  '/tmp/emoji \u{1F680}',
  '/',
];

typedef _FolderCreation = ({String path, bool isRecursive});

final class _PickerUnderTest {
  const _PickerUnderTest({
    required this.picker,
    required this.countAsks,
    required this.isCreatingFolders,
  });

  final FolderPicker picker;
  final int Function() countAsks;
  final bool isCreatingFolders;
}

final class _AnsweringChannel {
  _AnsweringChannel({required this.chosenFolder});

  final String? chosenFolder;
  final List<MethodCall> askedCalls = <MethodCall>[];

  Future<Object?> answer(MethodCall call) async {
    askedCalls.add(call);
    return chosenFolder;
  }
}

typedef _PickerBuilder = _PickerUnderTest Function(String? chosenFolder);

final class _RecordingDirectory extends Fake implements Directory {
  _RecordingDirectory({required this.path, required this.creations});

  @override
  final String path;
  final List<_FolderCreation> creations;

  @override
  Future<Directory> create({bool recursive = false}) async {
    creations.add((path: path, isRecursive: recursive));
    return this;
  }
}

_AnsweringChannel _answerChannel(MethodChannel channel, String? chosenFolder) {
  final _AnsweringChannel answering = _AnsweringChannel(
    chosenFolder: chosenFolder,
  );
  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  messenger.setMockMethodCallHandler(channel, answering.answer);
  addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  return answering;
}

_PickerUnderTest _buildPlatformPicker(String? chosenFolder) {
  final _AnsweringChannel answering = _answerChannel(
    _fileSelectorChannel,
    chosenFolder,
  );

  return _PickerUnderTest(
    picker: const PlatformFolderPicker(),
    countAsks: () => answering.askedCalls.length,
    isCreatingFolders: true,
  );
}

_PickerUnderTest _buildRunnerPicker(String? chosenFolder) {
  final _AnsweringChannel answering = _answerChannel(
    folderChannel,
    chosenFolder,
  );

  return _PickerUnderTest(
    picker: const RunnerFolderPicker(),
    countAsks: () => answering.askedCalls.length,
    isCreatingFolders: true,
  );
}

_PickerUnderTest _buildFixedPicker(String? chosenFolder) {
  final FixedFolderPicker picker = FixedFolderPicker(chosenFolder);

  return _PickerUnderTest(
    picker: picker,
    countAsks: () => picker.chooseCount,
    isCreatingFolders: false,
  );
}

final Map<String, _PickerBuilder> _pickerBuilders = <String, _PickerBuilder>{
  'platform_folder_picker': _buildPlatformPicker,
  'runner_folder_picker': _buildRunnerPicker,
  'fixed_folder_picker': _buildFixedPicker,
};

Future<T> _recordFolderCreations<T>(
  List<_FolderCreation> creations,
  Future<T> Function() body,
) {
  return IOOverrides.runZoned(
    body,
    createDirectory: (String path) =>
        _RecordingDirectory(path: path, creations: creations),
  );
}

String? _randomChoice(Random random) {
  if (random.nextInt(_cancelOneIn) == 0) {
    return null;
  }
  return buildTemporaryFolderPath(randomText(random));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final MapEntry<String, _PickerBuilder> entry
      in _pickerBuilders.entries) {
    final String typeName = entry.key;
    final _PickerBuilder buildPicker = entry.value;

    test(
      'test_${typeName}_choose_folder_property_returns_the_choice',
      () async {
        final Random random = seededRandom(68701);

        for (int i = 0; i < widgetPropertyIterations; i += 1) {
          final String? chosenFolder = _randomChoice(random);
          final _PickerUnderTest underTest = buildPicker(chosenFolder);

          expect(await underTest.picker.chooseFolder(), chosenFolder);
        }
      },
    );

    test('test_${typeName}_choose_folder_property_keeps_unusual_paths_'
        'verbatim', () async {
      for (final String unusualPath in _unusualFolderPaths) {
        final _PickerUnderTest underTest = buildPicker(unusualPath);

        expect(await underTest.picker.chooseFolder(), unusualPath);
      }
    });

    test('test_${typeName}_choose_folder_property_asks_once_and_creates_'
        'nothing', () async {
      final Random random = seededRandom(68702);
      final _PickerUnderTest underTest = buildPicker(_randomChoice(random));
      final List<_FolderCreation> creations = <_FolderCreation>[];
      final int callCount = 1 + random.nextInt(_largestCallCount);

      for (int i = 0; i < callCount; i += 1) {
        await _recordFolderCreations(creations, underTest.picker.chooseFolder);
      }

      expect(creations, isEmpty);
      expect(underTest.countAsks(), callCount);
    });

    test('test_${typeName}_prepare_new_projects_folder_property_ends_in_'
        'agon', () async {
      final List<_FolderCreation> creations = <_FolderCreation>[];
      final _PickerUnderTest underTest = buildPicker(null);

      final String folder = await _recordFolderCreations(
        creations,
        underTest.picker.prepareNewProjectsFolder,
      );
      final List<String> parts = folder.split(Platform.pathSeparator);
      final String doubledSeparator = Platform.pathSeparator * 2;

      expect(parts.last, _newProjectsFolderName);
      expect(folder, startsWith(Platform.pathSeparator));
      expect(folder.contains(doubledSeparator), isFalse);
    });

    test('test_${typeName}_prepare_new_projects_folder_property_same_folder_'
        'without_asking', () async {
      final Random random = seededRandom(68703);
      final _PickerUnderTest underTest = buildPicker(_randomChoice(random));
      final List<_FolderCreation> creations = <_FolderCreation>[];
      final Set<String> folders = <String>{};
      final int callCount = 1 + random.nextInt(_largestCallCount);

      for (int i = 0; i < callCount; i += 1) {
        folders.add(
          await _recordFolderCreations(
            creations,
            underTest.picker.prepareNewProjectsFolder,
          ),
        );
      }

      expect(folders.length, 1);
      expect(underTest.countAsks(), 0);
    });

    test('test_${typeName}_prepare_new_projects_folder_property_creates_'
        'the_folder_it_returns', () async {
      final _PickerUnderTest underTest = buildPicker(null);
      final List<_FolderCreation> creations = <_FolderCreation>[];

      final String folder = await _recordFolderCreations(
        creations,
        underTest.picker.prepareNewProjectsFolder,
      );

      if (!underTest.isCreatingFolders) {
        expect(creations, isEmpty);
        return;
      }
      expect(creations, <_FolderCreation>[(path: folder, isRecursive: true)]);
      expect(folder, describeNewProjectsFolder(Platform.environment));
    });
  }
}
