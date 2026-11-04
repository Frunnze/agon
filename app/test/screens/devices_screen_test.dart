import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/inline_link.dart';

import '../support/app_harness.dart';
import '../support/form_finders.dart';
import '../support/random_inputs.dart';
import '../support/workspace_device_finders.dart';

const String _revokeWarning =
    'Its key stops working in every workspace at once. To come back, it has '
    'to be paired again.';
const String _noCopyNote =
    'Shared by all your workspaces. Pair once, revoke once. Clients and '
    'runners keep no copy of the workspace data.';

Future<void> openRevokeDialog(WidgetTester tester, int rowIndex) async {
  await tapVisible(tester, find.text('Revoke').at(rowIndex));
  await pumpFrames(tester);
}

Future<AppNavigation> _pumpDevices(
  WidgetTester tester, {
  required Size size,
  required AppDependencies dependencies,
}) {
  return pumpApp(
    tester,
    size: size,
    route: const SectionRoute(AppSection.devices),
    dependencies: dependencies,
  );
}

int _countAcmeMembers(AppDependencies dependencies) {
  int members = 0;
  for (final Device device in dependencies.deviceRepository.listDevices()) {
    if (device.workspaces.contains(GalleryWorkspaceIds.acme)) {
      members += 1;
    }
  }
  return members;
}

void main() {
  for (final Size size in <Size>[phoneSize, desktopSize]) {
    testWidgets('devices match the gallery at ${size.width}', (
      WidgetTester tester,
    ) async {
      await _pumpDevices(
        tester,
        size: size,
        dependencies: buildGalleryDependencies(),
      );

      for (final String text in <String>[
        'In acme',
        'Add a device',
        'All your devices',
        'Pair a device',
        _noCopyNote,
        'This device · Computer',
        'This device · Computer · acme, personal',
        'Phone · acme, personal',
        'Computer · acme',
        'App server',
        'Backup server',
        'Runner',
        'Holds the data',
        'Has a copy · Last copied 3 days ago',
        'No copy',
        'Online',
        'Last seen 1 min ago',
        'Last seen 3 days ago',
      ]) {
        expect(find.text(text), findsWidgets, reason: text);
      }
      expect(
        find.textContaining(
          'Removing a device here only takes it out of acme.',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(findWorkspaceDeviceRemoveButtons('acme'), findsNWidgets(6));
      expect(find.text('Revoke'), findsNWidgets(6));
    });
  }

  testWidgets('test_devices_screen_property_remove_takes_device_out', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9901);
    final AppDependencies dependencies = buildGalleryDependencies();
    await _pumpDevices(tester, size: desktopSize, dependencies: dependencies);

    final Finder removeButtons = findWorkspaceDeviceRemoveButtons('acme');
    for (int i = 0; i < 3; i += 1) {
      final int buttonCount = tester.widgetList(removeButtons).length;
      final int chosen = random.nextInt(buttonCount);
      await tapVisible(tester, removeButtons.at(chosen));
      await pumpFrames(tester);

      expect(removeButtons, findsNWidgets(buttonCount - 1));
      expect(_countAcmeMembers(dependencies), buttonCount);
      expect(find.text('Revoke'), findsNWidgets(6));
    }
  });

  testWidgets('a removed device can be added back to the workspace', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    await dependencies.deviceRepository.removeDeviceFromWorkspace(
      GalleryDeviceIds.gpuBox,
      GalleryWorkspaceIds.acme,
    );
    await _pumpDevices(tester, size: desktopSize, dependencies: dependencies);
    expect(findWorkspaceDeviceRemoveButtons('acme'), findsNWidgets(5));

    await tapVisible(tester, find.text('Add a device'));
    await pumpFrames(tester);
    expect(find.text('Add a device to acme'), findsOneWidget);
    await tester.tap(find.text('Add'));
    await pumpFrames(tester);

    expect(findWorkspaceDeviceRemoveButtons('acme'), findsNWidgets(6));
    expect(
      dependencies.deviceRepository
          .findDevice(GalleryDeviceIds.gpuBox)
          .workspaces,
      contains(GalleryWorkspaceIds.acme),
    );
  });

  testWidgets('the removal note links to all your devices on the page', (
    WidgetTester tester,
  ) async {
    final AppNavigation navigation = await _pumpDevices(
      tester,
      size: phoneSize,
      dependencies: buildGalleryDependencies(),
    );
    final Finder link = find.widgetWithText(InlineLink, 'All your devices');
    final Finder pairButton = find.text('Pair a device');
    expect(tester.getTopLeft(pairButton).dy > phoneSize.height, isTrue);

    await tester.tap(link);
    await pumpFrames(tester);

    expect(navigation.currentRoute, const SectionRoute(AppSection.devices));
    final double pairTop = tester.getTopLeft(pairButton).dy;
    expect(pairTop >= 0 && pairTop < phoneSize.height, isTrue);
  });

  testWidgets('revoking a device takes one tap in the dialog', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    await _pumpDevices(tester, size: desktopSize, dependencies: dependencies);

    await openRevokeDialog(tester, 4);
    for (final String text in <String>[
      'Revoke old-macbook?',
      _revokeWarning,
      'Used in',
      '12 March 2026, approved by air-laptop',
    ]) {
      expect(find.text(text), findsWidgets, reason: text);
    }
    expect(find.textContaining('passkey'), findsNothing);

    await tester.tap(find.text('Keep device'));
    await pumpFrames(tester);
    expect(
      dependencies.deviceRepository
          .findDevice(GalleryDeviceIds.oldMacbook)
          .revoked,
      isFalse,
    );

    await openRevokeDialog(tester, 4);
    await tester.tap(find.text('Revoke device'));
    await pumpFrames(tester);

    expect(
      dependencies.deviceRepository
          .findDevice(GalleryDeviceIds.oldMacbook)
          .revoked,
      isTrue,
    );
    expect(find.text('old-macbook'), findsNothing);
    expect(find.text('Revoke'), findsNWidgets(5));
    expect(findWorkspaceDeviceRemoveButtons('acme'), findsNWidgets(5));
  });
}
