import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/app_server_group.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/forms/switch_field.dart';

import '../support/app_harness.dart';
import '../support/random_inputs.dart';
import '../support/server_group_repositories.dart';

const String _backupHint =
    'This computer keeps a live copy and takes over when the server is off.';
const List<String> _refusals = <String>[
  'the app server keeps no backups',
  'this device already keeps the app server',
  'could not reach the app server: down',
];

Future<void> _openSettings(
  WidgetTester tester,
  ScriptedServerBackupRepository repository,
) async {
  final AppDependencies dependencies = replaceRepositories(
    buildGalleryDependencies(),
    workspaceRepository: repository,
  );
  await pumpApp(
    tester,
    size: desktopSize,
    route: const SectionRoute(AppSection.settings),
    dependencies: dependencies,
  );
}

SwitchToggle _readToggle(WidgetTester tester) {
  return tester.widget<SwitchToggle>(findServerBackupToggle());
}

final class _FirstStartRefused {
  _FirstStartRefused(this._inner);

  final FakeWorkspaceRepository _inner;
  int _attempts = 0;

  Future<AppServerGroup> startBackup() async {
    _attempts += 1;
    if (_attempts == 1) {
      throw StateError(_refusals.first);
    }
    return _inner.startServerBackup();
  }
}

void main() {
  testWidgets('the toggle is disabled while the change runs', (
    WidgetTester tester,
  ) async {
    final FakeWorkspaceRepository inner = buildServerGroupRepository(
      galleryAppServerGroup,
    );
    final Completer<AppServerGroup> answer = Completer<AppServerGroup>();
    final ScriptedServerBackupRepository repository =
        ScriptedServerBackupRepository(
          inner: inner,
          startBackup: () => answer.future,
        );
    await _openSettings(tester, repository);

    await tester.tap(findServerBackupToggle());
    await tester.pump();

    expect(repository.startCount, 1);
    expect(_readToggle(tester).onChanged, isNull);
    await tester.tap(findServerBackupToggle(), warnIfMissed: false);
    await tester.pump();
    expect(repository.startCount, 1);

    answer.complete(inner.findAppServerGroup());
    await pumpFrames(tester);

    expect(_readToggle(tester).onChanged, isNotNull);
    expect(find.text(_backupHint), findsOneWidget);
  });

  testWidgets('test_server_backup_toggle_property_refusal_is_shown', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9931);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String refusal = '${pickOne(random, _refusals)} $i';
      final FakeWorkspaceRepository inner = buildServerGroupRepository(
        galleryAppServerGroup,
      );
      final ScriptedServerBackupRepository repository =
          ScriptedServerBackupRepository(
            inner: inner,
            startBackup: () async => throw StateError(refusal),
          );
      await _openSettings(tester, repository);

      await tester.tap(findServerBackupToggle());
      await pumpFrames(tester);

      expect(find.text(refusal), findsOneWidget);
      expect(find.text(_backupHint), findsNothing);
      expect(_readToggle(tester).value, isFalse);
      expect(_readToggle(tester).onChanged, isNotNull);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('a later success clears the refusal', (
    WidgetTester tester,
  ) async {
    final FakeWorkspaceRepository inner = buildServerGroupRepository(
      galleryAppServerGroup,
    );
    final _FirstStartRefused script = _FirstStartRefused(inner);
    final ScriptedServerBackupRepository repository =
        ScriptedServerBackupRepository(
          inner: inner,
          startBackup: script.startBackup,
        );
    await _openSettings(tester, repository);

    await tester.tap(findServerBackupToggle());
    await pumpFrames(tester);
    expect(find.text(_refusals.first), findsOneWidget);

    await tester.tap(findServerBackupToggle());
    await pumpFrames(tester);

    expect(find.text(_refusals.first), findsNothing);
    expect(find.text(_backupHint), findsOneWidget);
    expect(_readToggle(tester).value, isTrue);
  });
}
