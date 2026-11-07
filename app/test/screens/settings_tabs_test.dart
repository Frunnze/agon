import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_audit.dart';
import 'package:agent_orchestration/data/models/audit.dart';
import 'package:agent_orchestration/screens/settings.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/tab_strip.dart';

import '../support/app_harness.dart';
import '../support/form_finders.dart';
import '../support/random_inputs.dart';

const List<String> _tabLabels = <String>[
  'Server',
  'Commands and pushes',
  "Files agents can't read",
  'Audit log',
];

const Map<String, List<String>> _partsOfTab = <String, List<String>>{
  'Server': <String>['App server', 'Keep a backup of the server'],
  'Commands and pushes': <String>['Ask me'],
  "Files agents can't read": <String>['Reset to defaults', 'Add pattern'],
  'Audit log': <String>['The log is intact'],
};

const List<String> _textsThatLeftSettings = <String>[
  'General',
  'Runners',
  'Devices in acme',
  'Add one of your devices',
  'Your devices',
];

Finder _findInSettings(String text) {
  return find.descendant(
    of: find.byType(WorkspaceSettingsScreen),
    matching: find.text(text),
  );
}

Future<void> openSettingsTab(WidgetTester tester, String tab) async {
  await tapVisible(
    tester,
    find.descendant(of: find.byType(TabStrip), matching: find.text(tab)),
  );
  await pumpFrames(tester);
}

void _expectOnlyPartsOf(String shownTab) {
  for (final MapEntry<String, List<String>> tab in _partsOfTab.entries) {
    final Matcher expected = tab.key == shownTab ? findsWidgets : findsNothing;
    for (final String part in tab.value) {
      expect(_findInSettings(part), expected, reason: '$shownTab: $part');
    }
  }
}

void main() {
  for (final Size size in <Size>[phoneSize, desktopSize]) {
    testWidgets('settings has its four tabs at ${size.width}', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        size: size,
        route: const SectionRoute(AppSection.settings),
        dependencies: buildGalleryDependencies(),
      );

      final TabStrip tabs = tester.widget<TabStrip>(find.byType(TabStrip));
      expect(tabs.labels, _tabLabels);
      expect(tabs.selectedIndex, 0);
      for (final String text in _textsThatLeftSettings) {
        expect(_findInSettings(text), findsNothing, reason: text);
      }
    });

    testWidgets('the server tab opens first at ${size.width}', (
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
        'Delete workspace',
        'App server',
        'main-mac',
        'Online',
      ]) {
        expect(_findInSettings(text), findsWidgets, reason: text);
      }
      _expectOnlyPartsOf('Server');
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

  testWidgets('test_settings_tabs_property_each_tab_shows_only_its_part', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(12201);
    await pumpApp(
      tester,
      size: desktopSize,
      route: const SectionRoute(AppSection.settings),
      dependencies: buildGalleryDependencies(),
    );

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String tab = pickOne(random, _tabLabels);
      await openSettingsTab(tester, tab);

      _expectOnlyPartsOf(tab);
      final Matcher deleteShown = tab == 'Server' ? findsOne : findsNothing;
      expect(_findInSettings('Delete workspace'), deleteShown, reason: tab);
    }
  });

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
      auditRepository: FakeAuditRepository(entries: entries),
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
}
