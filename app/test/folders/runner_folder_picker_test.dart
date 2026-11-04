import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/folder_picker.dart';
import 'package:agent_orchestration/folders/folder_picker_choice.dart';
import 'package:agent_orchestration/folders/platform_folder_picker.dart';
import 'package:agent_orchestration/folders/runner_folder_picker.dart';

import '../support/random_inputs.dart';

final class _AnsweringRunner {
  _AnsweringRunner({required this.chosenFolder});

  final String? chosenFolder;
  final List<String> methods = <String>[];

  Future<Object?> answer(MethodCall call) async {
    methods.add(call.method);
    return chosenFolder;
  }
}

_AnsweringRunner _answerFolderCalls({required String? chosenFolder}) {
  final _AnsweringRunner runner = _AnsweringRunner(chosenFolder: chosenFolder);
  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(folderChannel, runner.answer);
  addTearDown(() => messenger.setMockMethodCallHandler(folderChannel, null));
  return runner;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('test_build_platform_folder_picker_property_macos_asks_runner', () {
    for (final TargetPlatform platform in TargetPlatform.values) {
      final FolderPicker picker = buildPlatformFolderPicker(platform);
      if (platform == TargetPlatform.macOS) {
        expect(picker, isA<RunnerFolderPicker>(), reason: platform.name);
      } else {
        expect(picker, isA<PlatformFolderPicker>(), reason: platform.name);
      }
    }
  });

  test('test_choose_folder_property_returns_the_runner_choice', () async {
    final Random random = seededRandom(8501);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String? chosenFolder = random.nextBool()
          ? null
          : '${Directory.systemTemp.path}/${randomText(random)}';
      final _AnsweringRunner runner = _answerFolderCalls(
        chosenFolder: chosenFolder,
      );

      final String? answered = await const RunnerFolderPicker().chooseFolder();

      expect(answered, chosenFolder);
      expect(runner.methods, <String>[chooseFolderMethod]);
    }
  });
}
