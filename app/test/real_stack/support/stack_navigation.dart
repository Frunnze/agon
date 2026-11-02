import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/shell/side_rail.dart';
import 'package:agent_orchestration/widgets/inline_link.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

import 'stack_waiting.dart';

final RegExp _shownPairingCode = RegExp(r'^[0-9A-Z]{3}-[0-9A-Z]{3}$');

Finder findRailLink(String label) {
  return find.descendant(
    of: find.byType(SideRail),
    matching: find.text(label),
  );
}

Finder findPageTitle(String title) {
  return find.byWidgetPredicate(
    (Widget widget) => widget is PageHeader && widget.title == title,
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

Future<void> openYourDevices(WidgetTester tester) async {
  await openRailSection(tester, label: 'Settings', pageTitle: 'Settings');
  await tapAndWait(
    tester,
    find.widgetWithText(InlineLink, 'Your devices'),
    expected: findPageTitle('Your devices'),
  );
}

Future<void> tapButton(WidgetTester tester, String label) async {
  final Finder button = find.text(label);
  await tester.ensureVisible(button);
  await tester.pump();
  await tester.tap(button);
  await tester.pump();
}
