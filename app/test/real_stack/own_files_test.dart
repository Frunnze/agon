import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/repository_file_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart'
    as node;
import 'package:agent_orchestration/bridge/node/runner_settings.dart' as node;

import 'support/real_stack.dart';
import 'support/stack_files.dart';
import 'support/stack_folders.dart';
import 'support/stack_navigation.dart';
import 'support/stack_waiting.dart';
import 'support/task_steps.dart';

const String _cachedCloneFolderName = 'local_2etest_2facme_2fapp';
const String _readmeName = 'README.md';
const String _readmeText = 'hello';
const String _selfDialProblem = 'Connecting to ourself';

node.RunnerSettings _runAgentsHere() {
  return node.RunnerSettings(
    labels: const <String>['mac'],
    slotCapacity: 1,
    sandbox: const node.LocalProcessSandbox(),
    cloneUrlTemplate: null,
  );
}

Future<Directory> _prepareCopyOutsideTheStack() async {
  final Directory parent = Directory.systemTemp.createTempSync('own_copy_');
  addTearDown(() => parent.deleteSync(recursive: true));
  return createGitFolder(parent, _cachedCloneFolderName);
}

void _keepAsOwnCopy(RealStack stack, Directory preparedCopy) {
  final Directory cacheRoot = Directory(
    '${stack.workingDirectory.path}/node/repository-cache',
  )..createSync(recursive: true);
  preparedCopy.renameSync('${cacheRoot.path}/$_cachedCloneFolderName');
}

Future<bool> _isOfferedByThisComputer(RealStack stack) async {
  final node.AvailableRepositoryBranches? source =
      await findLocalRepositorySource(stack);
  return source?.runner.deviceId == stack.appDeviceId;
}

void main() {
  final bool isStackMissing = findRealStackSkipReason() != null;

  testWidgets(
    'test_own_files_property_a_runner_computer_reads_its_copy_at_once',
    (WidgetTester tester) async {
      final Directory preparedCopy = await askNode(
        tester,
        _prepareCopyOutsideTheStack,
      );
      final RealStack stack = await RealStack.openAsHostingRunner(
        tester,
        runner: _runAgentsHere(),
      );
      await askNode(tester, stack.server.stop);
      _keepAsOwnCopy(stack, preparedCopy);
      await createLocalProject(
        tester,
        stack: stack,
        agentAccess: node.AgentAccess.readOnly,
      );
      final bool isOfferedAtOnce = await askNode(
        tester,
        () => _isOfferedByThisComputer(stack),
      );
      expect(isOfferedAtOnce, isTrue);

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
      await waitUntilShown(tester, find.text(_readmeName));
      await tapAndWait(
        tester,
        find.text(_readmeName).last,
        expected: findPageTitle(_readmeName),
      );
      await waitUntilShown(
        tester,
        find.textContaining(_readmeText, findRichText: true),
      );

      expect(
        find.textContaining(_selfDialProblem, findRichText: true),
        findsNothing,
      );
      await stack.close(tester);
    },
    skip: isStackMissing,
    timeout: realStackTimeout,
  );
}
