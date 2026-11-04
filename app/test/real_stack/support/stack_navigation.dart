import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/shell/side_rail.dart';
import 'package:agent_orchestration/widgets/compact_page_header.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

import 'stack_waiting.dart';

final RegExp _shownPairingCode = RegExp(r'^[0-9A-Z]{3}-[0-9A-Z]{3}$');

Finder findRailLink(String label) {
  return find.descendant(
    of: find.byType(SideRail),
    matching: find.text(label),
  );
}

bool _isPageHeaderTitled(Widget widget, String title) {
  if (widget is PageHeader) {
    return widget.title == title;
  }
  return widget is CompactPageHeader && widget.title == title;
}

Finder findPageTitle(String title) {
  return find.byWidgetPredicate(
    (Widget widget) => _isPageHeaderTitled(widget, title),
  );
}

Finder findShownPairingCode() {
  return find.byWidgetPredicate((Widget widget) {
    if (widget is! Text) {
      return false;
    }
    final String? shownText = widget.data;
    return shownText != null && _shownPairingCode.hasMatch(shownText);
  });
}

String readShownPairingCode(WidgetTester tester) {
  final Text code = tester.widget<Text>(findShownPairingCode());
  return code.data!;
}

Future<void> openRailSection(
  WidgetTester tester, {
  required String label,
  required String pageTitle,
}) async {
  await tapAndWait(
    tester,
    findRailLink(label),
    expected: findPageTitle(pageTitle),
  );
}

Future<void> openDevices(WidgetTester tester) async {
  await openRailSection(tester, label: 'Devices', pageTitle: 'Devices');
}

Future<void> tapButton(WidgetTester tester, String label) async {
  final Finder button = find.text(label);
  await tester.ensureVisible(button);
  await tester.pump();
  await tester.tap(button);
  await tester.pump();
}
