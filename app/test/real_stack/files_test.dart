import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/repository_file_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/run_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart'
    as node;
import 'package:agent_orchestration/screens/files/path_breadcrumb.dart';

import '../support/form_finders.dart';
import 'support/real_stack.dart';
import 'support/runner_device.dart';
import 'support/stack_files.dart';
import 'support/stack_navigation.dart';
import 'support/stack_waiting.dart';
import 'support/task_steps.dart';

const String _taskTitle = 'Leave a change to browse';
const String _repositoryPath = 'acme/app';
const String _sourceFolder = 'src';
const String _sourceName = 'app.ts';
const String _sourceText = 'export const browsedAnswer = 42;\n';
const String _sourceMarker = 'browsedAnswer';
const String _assetsFolder = 'assets';
const String _iconName = 'icon.png';
const String _iconBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAIAAAADCAYAAAC56t6BAAAAEElEQVR42mNgKE39D8YY'
    'DACM/QsXI37HfwAAAABJRU5ErkJggg==';
const String _iconDimensions = '2 × 3';
const String _agentChangeName = 'CHANGES.md';
const String _defaultBranch = 'main';
const String _workFolderName = 'browse-work';
const List<String> _gitTestSettings = <String>[
  '-c',
  'user.name=Real Stack Test',
  '-c',
  'user.email=real-stack@example.com',
  '-c',
  'commit.gpgsign=false',
  '-c',
  'core.hooksPath=/dev/null',
];

Future<void> _runGit(Directory directory, List<String> arguments) async {
  final ProcessResult outcome = await Process.run('git', <String>[
    ..._gitTestSettings,
    ...arguments,
  ], workingDirectory: directory.path);
  if (outcome.exitCode != 0) {
    throw StateError('git ${arguments.first} failed: ${outcome.stderr}');
  }
}

Future<void> _addFilesToBrowse(Directory origin) async {
  final Directory work = Directory('${origin.parent.path}/$_workFolderName');
  await _runGit(origin.parent, <String>[
    'clone',
    '--quiet',
    origin.path,
    work.path,
  ]);
  File('${work.path}/$_sourceFolder/$_sourceName')
    ..createSync(recursive: true)
    ..writeAsStringSync(_sourceText);
  File('${work.path}/$_assetsFolder/$_iconName')
    ..createSync(recursive: true)
    ..writeAsBytesSync(base64Decode(_iconBase64));
  await _runGit(work, <String>['add', '--all']);
  await _runGit(work, <String>['commit', '--quiet', '-m', 'Add the app']);
  await _runGit(work, <String>['push', '--quiet', 'origin', _defaultBranch]);
}

Future<String?> _readTaskBranch(RealStack stack) async {
  final node.AvailableRepositoryBranches? source =
      await findLocalRepositorySource(stack);
  if (source == null || source.taskBranches.isEmpty) {
    return null;
  }
  return source.taskBranches.first;
}

Future<String> _waitForTaskBranch(WidgetTester tester, RealStack stack) async {
  final List<String> found = <String>[];
  await waitUntilNodeAgrees(
    tester,
    description: 'the runner offering its task branch',
    check: () async {
      final String? taskBranch = await _readTaskBranch(stack);
      if (taskBranch != null) {
        found.add(taskBranch);
      }
      return taskBranch != null;
    },
  );
  return found.last;
}

bool _serverHoldsText(RealStack stack, String text) {
  final Directory serverFolder = Directory(
    '${stack.workingDirectory.path}/server',
  );
  for (final FileSystemEntity entity in serverFolder.listSync(
    recursive: true,
  )) {
    if (entity is! File) {
      continue;
    }
    final String content = utf8.decode(
      entity.readAsBytesSync(),
      allowMalformed: true,
    );
    if (content.contains(text)) {
      return true;
    }
  }
  return false;
}

void main() {
  final bool isStackMissing = findRealStackSkipReason() != null;

  testWidgets(
    'test_project_files_property_shows_a_task_branch_through_the_runner',
    (WidgetTester tester) async {
      final RealStack stack = await RealStack.openWithAccount(tester);
      final RunnerDevice runner = await pairRunnerWithProject(
        tester,
        stack: stack,
        agentAccess: node.AgentAccess.readOnly,
      );
      await askNode(tester, () => _addFilesToBrowse(runner.originDirectory));
      await startNewTaskNow(
        tester,
        title: _taskTitle,
        details: 'Change the readme.',
      );
      await waitUntilRunStatus(
        tester,
        stack: stack,
        title: _taskTitle,
        status: node.RunStatus.done,
      );
      final String taskBranch = await _waitForTaskBranch(tester, stack);

      await openRailSection(tester, label: 'Projects', pageTitle: 'Projects');
      await tapAndWait(
        tester,
        find.text(localProjectName),
        expected: findPageTitle(localProjectName),
      );
      await tapAndWait(
        tester,
        find.text('Browse files'),
        expected: findPageTitle('Files'),
      );
      await waitUntilShown(
        tester,
        find.textContaining(runnerDeviceName, findRichText: true),
      );
      await tapWhenShown(tester, findFieldText('Branch', _defaultBranch));
      await tapWhenShown(tester, find.text(taskBranch).last);
      await waitUntilShown(tester, find.text(_agentChangeName));
      await tapWhenShown(tester, find.text(_sourceFolder));
      await tapAndWait(
        tester,
        find.text(_sourceName),
        expected: findPageTitle(_sourceName),
      );
      await waitUntilShown(
        tester,
        find.textContaining(_sourceMarker, findRichText: true),
      );
      final bool isCodeShown = find
          .textContaining(_sourceMarker, findRichText: true)
          .evaluate()
          .isNotEmpty;

      await tapAndWait(
        tester,
        find.descendant(
          of: find.byType(PathBreadcrumb),
          matching: find.text(_repositoryPath),
        ),
        expected: findPageTitle('Files'),
      );
      await tapWhenShown(tester, find.text(_assetsFolder));
      await tapAndWait(
        tester,
        find.text(_iconName),
        expected: findPageTitle(_iconName),
      );
      await waitUntilShown(
        tester,
        find.textContaining(_iconDimensions, findRichText: true),
      );

      expect(isCodeShown, isTrue);
      expect(
        find.textContaining(taskBranch, findRichText: true),
        findsWidgets,
      );
      expect(_serverHoldsText(stack, _sourceMarker), isFalse);
      await stack.close(tester);
    },
    skip: isStackMissing,
    timeout: realStackTimeout,
  );
}
