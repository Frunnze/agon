import 'dart:math';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/screens/settings.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/lists/responsive_list.dart';
import 'package:agent_orchestration/widgets/notice_banner.dart';
import 'package:agent_orchestration/widgets/page_section.dart';
import 'package:agent_orchestration/widgets/tab_strip.dart';

import '../support/app_harness.dart';
import '../support/form_finders.dart';
import '../support/random_inputs.dart';
import '../support/server_group_repositories.dart';
import '../support/widget_harness.dart';

typedef _GapMeasure = List<double> Function(WidgetTester tester);

const double _pageGap = 24;
const String _membersTitle = 'In acme';
const String _allDevicesTitle = 'All your devices';

final class _PageCase {
  const _PageCase({
    required this.name,
    required this.section,
    required this.tab,
    required this.buildDependencies,
    required this.measureGaps,
  });

  final String name;
  final AppSection section;
  final String? tab;
  final AppDependencies Function() buildDependencies;
  final _GapMeasure measureGaps;
}

double _gapBetween(Rect above, Rect below) => below.top - above.bottom;

Rect _findSectionRect(WidgetTester tester, String title) {
  return tester.getRect(
    find.byWidgetPredicate(
      (Widget widget) => widget is PageSection && widget.title == title,
    ),
  );
}

List<double> _measureServerGaps(WidgetTester tester) {
  final Rect tabs = tester.getRect(find.byType(TabStrip));
  final Rect server = tester.getRect(find.byType(AppServerSection));
  return <double>[_gapBetween(tabs, server)];
}

List<double> _measureDevicesGaps(WidgetTester tester) {
  final Rect members = _findSectionRect(tester, _membersTitle);
  final Rect allDevices = _findSectionRect(tester, _allDevicesTitle);
  return <double>[_gapBetween(members, allDevices)];
}

List<double> _measureServerDownGaps(WidgetTester tester) {
  final Rect banner = tester.getRect(find.byType(NoticeBanner));
  final Rect members = _findSectionRect(tester, _membersTitle);
  return <double>[_gapBetween(banner, members)];
}

List<double> _measureAuditGaps(WidgetTester tester) {
  final Rect banner = tester.getRect(find.byType(NoticeBanner));
  final Rect list = tester.getRect(find.byType(ResponsiveList));
  return <double>[_gapBetween(banner, list)];
}

const List<_PageCase> _pageCases = <_PageCase>[
  _PageCase(
    name: 'Server',
    section: AppSection.settings,
    tab: 'Server',
    buildDependencies: buildGalleryDependencies,
    measureGaps: _measureServerGaps,
  ),
  _PageCase(
    name: 'Devices',
    section: AppSection.devices,
    tab: null,
    buildDependencies: buildGalleryDependencies,
    measureGaps: _measureDevicesGaps,
  ),
  _PageCase(
    name: 'Devices with the server down',
    section: AppSection.devices,
    tab: null,
    buildDependencies: buildDependenciesWithServerDown,
    measureGaps: _measureServerDownGaps,
  ),
  _PageCase(
    name: 'Audit log',
    section: AppSection.settings,
    tab: 'Audit log',
    buildDependencies: buildGalleryDependencies,
    measureGaps: _measureAuditGaps,
  ),
];

Future<void> _openPage(
  WidgetTester tester, {
  required double width,
  required _PageCase pageCase,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpApp(
    tester,
    size: Size(width, desktopHeight),
    route: SectionRoute(pageCase.section),
    dependencies: pageCase.buildDependencies(),
  );
  final String? tab = pageCase.tab;
  if (tab == null) {
    return;
  }
  await tapVisible(
    tester,
    find.descendant(of: find.byType(TabStrip), matching: find.text(tab)),
  );
  await pumpFrames(tester);
}

void _expectBodyMuted(WidgetTester tester, Finder text) {
  final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(text);
  final TextStyle shownStyle = paragraph.text.style!;
  expect(shownStyle.fontSize, AppFontSizes.body, reason: '$text');
  expect(shownStyle.color, AppColors.inkMuted, reason: '$text');
}

void main() {
  testWidgets('test_settings_and_devices_property_blocks_use_page_gap', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(7921);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = randomWidth(
        random,
        least: narrowestWidth,
        most: widestWidth,
      );
      final _PageCase pageCase = pickOne(random, _pageCases);
      await _openPage(tester, width: width, pageCase: pageCase);

      for (final double gap in pageCase.measureGaps(tester)) {
        final String reason = '${pageCase.name} at width $width';
        expect(gap, closeTo(_pageGap, 0.5), reason: reason);
      }
    }
  });

  testWidgets('test_settings_and_devices_property_muted_text_is_body_text', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(7922);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = randomWidth(
        random,
        least: narrowestWidth,
        most: widestWidth,
      );
      await _openPage(tester, width: width, pageCase: _pageCases[1]);
      _expectBodyMuted(tester, find.textContaining('Removing a device here'));
      _expectBodyMuted(tester, find.text(_allDevicesTitle).first);

      await _openPage(tester, width: width, pageCase: _pageCases[2]);
      _expectBodyMuted(tester, find.textContaining('Last connected 14:12'));

      await _openPage(tester, width: width, pageCase: _pageCases[3]);
      _expectBodyMuted(tester, find.textContaining('Latest '));
      _expectBodyMuted(tester, find.text('14:09'));
    }
  });
}
