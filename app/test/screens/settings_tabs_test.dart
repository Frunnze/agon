import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_audit.dart';
import 'package:agent_orchestration/data/models/audit.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../support/app_harness.dart';
import '../support/server_group_repositories.dart';

const String _serverDownNotice =
    'Runners on this network still work. Runs for gpu-box wait until the '
    'server is back.';

Future<void> openSettingsTab(WidgetTester tester, String tab) async {
  await tester.tap(find.text(tab));
  await pumpFrames(tester);
}

void main() {
  for (final Size size in <Size>[phoneSize, desktopSize]) {
    testWidgets('general settings match the gallery at ${size.width}', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        size: size,
        route: const SectionRoute(AppSection.settings),
        dependencies: buildGalleryDependencies(),
      );

      for (final String text in <String>[
        'For the acme workspace.',
        'General',
        'Runners',
        'Audit log',
        'App server',
        'main-mac',
        'Online',
        'Devices in acme',
        'Add one of your devices',
        'air-laptop',
        'This device',
        'old-macbook',
        'Client and runner',
        '3 days ago',
        '2 h ago',
      ]) {
        expect(find.text(text), findsWidgets, reason: text);
      }
      expect(find.text('Remove'), findsNWidgets(6));
    });

    testWidgets('runners tab matches the gallery at ${size.width}', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        size: size,
        route: const SectionRoute(AppSection.settings),
        dependencies: buildGalleryDependencies(),
      );
      await openSettingsTab(tester, 'Runners');

      for (final String text in <String>[
        '3 of 4 online · 5 free slots',
        'mac-studio',
        'xcode',
        '1 of 4 busy',
        '0 of 1 busy',
        'Relay',
        'None free',
        'Last seen 3 days ago',
        'Offline',
      ]) {
        expect(find.text(text), findsWidgets, reason: text);
      }
      expect(find.text('Direct'), findsNWidgets(2));
      expect(find.text('Online'), findsNWidgets(3));
    });

    testWidgets('audit log matches the gallery at ${size.width}', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        size: size,
        route: const SectionRoute(AppSection.settings),
        dependencies: buildGalleryDependencies(),
      );
      await openSettingsTab(tester, 'Audit log');

      for (final String text in <String>[
        'The log is intact',
        'Asked to push 3 commits',
        'release #42 · acme/app',
        '9f3a…c210',
        '14:09',
        'Yesterday 11:15',
        '2 days ago',
        'Paired gpu-box as a runner',
      ]) {
        expect(find.text(text), findsWidgets, reason: text);
      }
      expect(
        find.textContaining('1,284 entries. Each one is signed'),
        findsOne,
      );
      expect(find.text('Latest 9f3a…c210'), findsOneWidget);
    });
  }

  testWidgets('a broken audit chain is reported', (WidgetTester tester) async {
    final List<AuditEntry> entries = <AuditEntry>[...galleryAuditEntries];
    final AuditEntry newest = entries.first;
    entries[0] = AuditEntry(
      index: newest.index,
      at: newest.at,
      deviceId: newest.deviceId,
      event: newest.event,
      detail: newest.detail,
      previousHash: 'tampered',
      hash: newest.hash,
    );
    final AppDependencies dependencies = replaceRepositories(
      buildGalleryDependencies(),
      auditRepository: FakeAuditRepository(
        entries: entries,
        summary: const ChainSummary(entryCount: 1284, headHash: 'head'),
      ),
    );
    await pumpApp(
      tester,
      size: desktopSize,
      route: const SectionRoute(AppSection.settings),
      dependencies: dependencies,
    );
    await openSettingsTab(tester, 'Audit log');

    expect(find.text('The log is broken'), findsOneWidget);
    expect(find.text('The log is intact'), findsNothing);
  });

  testWidgets('the server-down runners list matches the gallery', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildDependenciesWithServerDown();
    await pumpApp(
      tester,
      size: desktopSize,
      route: const SectionRoute(AppSection.settings),
      dependencies: dependencies,
    );
    await openSettingsTab(tester, 'Runners');

    for (final String text in <String>[
      '2 of 4 reachable',
      "Can't reach the app server",
      _serverDownNotice,
      'Last connected 14:12 · trying every 10 seconds',
      'Unknown',
      'Needs the server',
      'Unreachable',
    ]) {
      expect(find.text(text), findsWidgets, reason: text);
    }
    expect(find.text('This network'), findsNWidgets(2));

    await tester.tap(find.text('Try now'));
    await pumpFrames(tester);

    expect(find.text("Can't reach the app server"), findsNothing);
    expect(find.text('3 of 4 online · 5 free slots'), findsOneWidget);
  });
}
