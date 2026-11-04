import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/app_server_group.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/forms/switch_field.dart';
import 'package:agent_orchestration/widgets/page_section.dart';

import '../support/app_harness.dart';
import '../support/form_finders.dart';
import '../support/random_inputs.dart';
import '../support/server_group_repositories.dart';

const String _activeText =
    'Active server · relays messages and keeps the run queue. It sees only '
    'encrypted data.';
const String _backupText =
    'Backup · keeps a live copy and takes over when the active server is '
    'off.';
const String _backupHint =
    'This computer keeps a live copy and takes over when the server is off.';
const String _activeHint = 'This computer is the active server.';
const String _standaloneText =
    'Relays messages and keeps the run queue. It sees only encrypted data.';
const String _galleryServerHost = 'peer link 4f7a2c19';
const DeviceId _unknownServerId = DeviceId('0123456789abcdef0123456789abcdef');

Future<void> _openSettings(
  WidgetTester tester, {
  required Size size,
  required AppDependencies dependencies,
}) async {
  await pumpApp(
    tester,
    size: size,
    route: const SectionRoute(AppSection.settings),
    dependencies: dependencies,
  );
}

SwitchToggle _readToggle(WidgetTester tester) {
  return tester.widget<SwitchToggle>(findServerBackupToggle());
}

Finder _findInServerSection(String text) {
  return find.descendant(
    of: find.byWidgetPredicate(
      (Widget widget) => widget is PageSection && widget.title == 'App server',
    ),
    matching: find.text(text),
  );
}

String _describeShownName(DeviceId deviceId) {
  for (final Device device in galleryDevices) {
    if (device.id == deviceId) {
      return device.name;
    }
  }
  return shortenIdentifier(deviceId.value);
}

void main() {
  for (final Size size in <Size>[phoneSize, desktopSize]) {
    testWidgets('server backups match the gallery at ${size.width}', (
      WidgetTester tester,
    ) async {
      await _openSettings(
        tester,
        size: size,
        dependencies: buildGalleryDependencies(),
      );

      for (final String text in <String>[
        'App server',
        'main-mac',
        _activeText,
        'Online',
        'old-macbook',
        _backupText,
        keepBackupLabel,
        _backupHint,
      ]) {
        expect(find.text(text), findsWidgets, reason: text);
      }
      expect(find.text(_galleryServerHost), findsNothing);
      expect(_readToggle(tester).value, isFalse);
      expect(_readToggle(tester).onChanged, isNotNull);
    });

    testWidgets('turning the backup on matches the gallery at ${size.width}', (
      WidgetTester tester,
    ) async {
      final AppDependencies dependencies = buildGalleryDependencies();
      await _openSettings(tester, size: size, dependencies: dependencies);

      await tapVisible(tester, findServerBackupToggle());
      await pumpFrames(tester);

      expect(find.text('This device · $_backupText'), findsOneWidget);
      expect(_readToggle(tester).value, isTrue);
      expect(
        dependencies.workspaceRepository
            .findAppServerGroup()
            .thisDeviceStanding,
        ThisDeviceStanding.backup,
      );

      await tapVisible(tester, findServerBackupToggle());
      await pumpFrames(tester);

      expect(find.text('This device · $_backupText'), findsNothing);
      expect(_readToggle(tester).value, isFalse);
    });
  }

  testWidgets('the toggle is hidden when this device cannot keep backups', (
    WidgetTester tester,
  ) async {
    final AppServerGroup group = AppServerGroup(
      members: galleryAppServerGroupMembers(),
      thisDeviceStanding: ThisDeviceStanding.none,
      canKeepBackup: false,
    );
    await _openSettings(
      tester,
      size: phoneSize,
      dependencies: buildDependenciesWithServerGroup(group),
    );

    expect(find.text(_activeText), findsOneWidget);
    expect(find.text(_backupText), findsOneWidget);
    expect(findServerBackupToggle(), findsNothing);
    expect(find.text(keepBackupLabel), findsNothing);
  });

  testWidgets('a server without backups keeps the single address row', (
    WidgetTester tester,
  ) async {
    final AppServerGroup group = AppServerGroup(
      members: const <AppServerMember>[],
      thisDeviceStanding: ThisDeviceStanding.none,
      canKeepBackup: true,
    );
    await _openSettings(
      tester,
      size: desktopSize,
      dependencies: buildDependenciesWithServerGroup(group),
    );

    expect(find.text(_galleryServerHost), findsOneWidget);
    expect(find.text(_standaloneText), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
    expect(find.text(_activeText), findsNothing);
    expect(findServerBackupToggle(), findsNothing);
  });

  testWidgets('the toggle stays on and locked on the active server', (
    WidgetTester tester,
  ) async {
    final AppServerGroup group = AppServerGroup(
      members: const <AppServerMember>[
        AppServerMember(
          deviceId: GalleryDeviceIds.oldMacbook,
          standing: ServerStanding.backup,
          copy: null,
        ),
        AppServerMember(
          deviceId: GalleryDeviceIds.airLaptop,
          standing: ServerStanding.active,
          copy: null,
        ),
      ],
      thisDeviceStanding: ThisDeviceStanding.active,
      canKeepBackup: true,
    );
    final AppDependencies dependencies = buildDependenciesWithServerGroup(
      group,
    );
    await _openSettings(tester, size: phoneSize, dependencies: dependencies);

    expect(find.text('This device · $_activeText'), findsOneWidget);
    expect(find.text(_activeHint), findsOneWidget);
    expect(find.text(_backupHint), findsNothing);
    expect(_readToggle(tester).value, isTrue);
    expect(_readToggle(tester).onChanged, isNull);
    expect(
      tester.getTopLeft(find.text('This device · $_activeText')).dy,
      lessThan(tester.getTopLeft(find.text(_backupText)).dy),
    );

    await tester.tap(findServerBackupToggle(), warnIfMissed: false);
    await pumpFrames(tester);

    expect(dependencies.workspaceRepository.findAppServerGroup(), same(group));
  });

  testWidgets('test_general_settings_property_every_server_is_named', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9921);
    final List<DeviceId> candidates = <DeviceId>[
      for (final Device device in galleryDevices) device.id,
      _unknownServerId,
    ];

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DeviceId activeServerId = pickOne(random, candidates);
      final List<AppServerMember> members = <AppServerMember>[
        AppServerMember(
          deviceId: activeServerId,
          standing: ServerStanding.active,
          copy: null,
        ),
        for (final DeviceId deviceId in candidates)
          if (deviceId != activeServerId && random.nextBool())
            AppServerMember(
              deviceId: deviceId,
              standing: ServerStanding.backup,
              copy: null,
            ),
      ];
      final AppServerGroup group = AppServerGroup(
        members: members,
        thisDeviceStanding: ThisDeviceStanding.none,
        canKeepBackup: random.nextBool(),
      );
      await _openSettings(
        tester,
        size: desktopSize,
        dependencies: buildDependenciesWithServerGroup(group),
      );

      for (final AppServerMember member in members) {
        final String shownName = _describeShownName(member.deviceId);
        expect(
          _findInServerSection(shownName),
          findsOneWidget,
          reason: shownName,
        );
      }
      expect(
        findServerBackupToggle(),
        group.canKeepBackup ? findsOneWidget : findsNothing,
      );
    }
  });
}

List<AppServerMember> galleryAppServerGroupMembers() {
  return buildGalleryDependencies().workspaceRepository
      .findAppServerGroup()
      .members;
}
