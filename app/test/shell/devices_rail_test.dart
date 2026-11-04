import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/screens/devices/devices_screen.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/shell/bottom_tabs.dart';
import 'package:agent_orchestration/shell/side_rail.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

import '../support/app_harness.dart';
import '../support/random_inputs.dart';

const List<AppSection> _expectedRailSections = <AppSection>[
  AppSection.approvals,
  AppSection.tasks,
  AppSection.jobs,
  AppSection.projects,
  AppSection.workflows,
  AppSection.skills,
  AppSection.rules,
  AppSection.devices,
  AppSection.settings,
];

Finder _findRailLink(String label) {
  return find.descendant(
    of: find.byType(SideRail),
    matching: find.text(label),
  );
}

Finder _findPageTitle(String title) {
  return find.byWidgetPredicate(
    (Widget widget) => widget is PageHeader && widget.title == title,
  );
}

void main() {
  test('the rail has one devices item right before settings', () {
    expect(railSections, _expectedRailSections);
    expect(AppSection.devices.label, 'Devices');
    final List<String> labels = <String>[
      for (final AppSection section in AppSection.values) section.label,
    ];
    expect(labels, isNot(contains('Runners')));
    expect(labels, isNot(contains('Your devices')));
  });

  testWidgets('the rail opens the devices page on desktop', (
    WidgetTester tester,
  ) async {
    final AppNavigation navigation = await pumpApp(
      tester,
      size: desktopSize,
      route: const SectionRoute(AppSection.tasks),
      dependencies: buildGalleryDependencies(),
    );
    expect(_findRailLink('Runners'), findsNothing);
    final double rulesTop = tester.getTopLeft(_findRailLink('Rules')).dy;
    final double devicesTop = tester.getTopLeft(_findRailLink('Devices')).dy;
    final double settingsTop = tester.getTopLeft(_findRailLink('Settings')).dy;
    expect(rulesTop < devicesTop && devicesTop < settingsTop, isTrue);

    await tester.tap(_findRailLink('Devices'));
    await pumpFrames(tester);

    expect(navigation.currentRoute, const SectionRoute(AppSection.devices));
    expect(find.byType(DevicesScreen), findsOneWidget);
    expect(_findPageTitle('Devices'), findsOneWidget);
    expect(find.text('In acme'), findsOneWidget);
    expect(find.text('All your devices'), findsWidgets);
  });

  testWidgets('phones reach devices through more', (
    WidgetTester tester,
  ) async {
    final AppNavigation navigation = await pumpApp(
      tester,
      size: phoneSize,
      route: const SectionRoute(AppSection.tasks),
      dependencies: buildGalleryDependencies(),
    );

    await tester.tap(
      find.descendant(
        of: find.byType(BottomTabs),
        matching: find.text('More'),
      ),
    );
    await pumpFrames(tester);
    expect(find.text('Runners'), findsNothing);
    await tester.tap(find.text('Devices'));
    await pumpFrames(tester);

    expect(navigation.currentRoute, const SectionRoute(AppSection.devices));
    expect(_findPageTitle('Devices'), findsOneWidget);
  });

  testWidgets('old routes to your devices land on the devices section', (
    WidgetTester tester,
  ) async {
    for (final Size size in <Size>[phoneSize, desktopSize]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpApp(
        tester,
        size: size,
        route: const SectionRoute(AppSection.devices),
        dependencies: buildGalleryDependencies(),
      );

      expect(_findPageTitle('Devices'), findsOneWidget);
      expect(_findPageTitle('Your devices'), findsNothing);
      expect(find.text('Pair a device'), findsOneWidget);
      expect(find.text('Add a device'), findsOneWidget);
    }
  });

  test('test_find_bottom_tab_for_property_devices_live_in_more', () {
    final Random random = seededRandom(12101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppSection section = pickOne(random, <AppSection>[
        AppSection.devices,
        AppSection.settings,
      ]);

      expect(findBottomTabFor(section), AppSection.more);
    }
  });

  test('test_runner_detail_route_property_belongs_to_devices', () {
    final Random random = seededRandom(12102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DeviceId runnerId = pickOne(random, <DeviceId>[
        GalleryDeviceIds.macStudio,
        GalleryDeviceIds.gpuBox,
        GalleryDeviceIds.officeServer,
        GalleryDeviceIds.oldMacbook,
      ]);

      expect(RunnerDetailRoute(runnerId).section, AppSection.devices);
    }
    expect(const PairingCodeRoute().section, AppSection.devices);
    expect(const PairingApprovalRoute().section, AppSection.devices);
  });
}
