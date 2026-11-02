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
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/theme/layout_size.dart';
import 'package:agent_orchestration/widgets/lists/responsive_list.dart';
import 'package:agent_orchestration/widgets/notice_banner.dart';
import 'package:agent_orchestration/widgets/page_section.dart';

import '../support/app_harness.dart';
import '../support/form_finders.dart';
import '../support/random_inputs.dart';
import '../support/server_group_repositories.dart';
import '../support/widget_harness.dart';

typedef _GapMeasure = List<double> Function(WidgetTester tester);

const String _runnersSummary = '3 of 4 online · 5 free slots';
const String _serverDownSummary = '2 of 4 reachable';
const String _membersTitle = 'Devices in acme';

final class _TabCase {
  const _TabCase({
    required this.tab,
    required this.buildDependencies,
    required this.measureGaps,
  });

  final String tab;
  final AppDependencies Function() buildDependencies;
  final _GapMeasure measureGaps;
}

double _expectedPageGap(double width) {
  if (LayoutSize.forWidth(width).isCompact) {
    return AppSpacing.space5;
  }
  return AppSpacing.space6;
}

double _gapBetween(Rect above, Rect below) => below.top - above.bottom;

List<double> _measureGeneralGaps(WidgetTester tester) {
  final Rect server = tester.getRect(find.byType(AppServerSection));
  final Rect members = tester.getRect(
    find.byWidgetPredicate(
      (Widget widget) =>
          widget is PageSection && widget.title == _membersTitle,
    ),
  );
  return <double>[_gapBetween(server, members)];
}

List<double> _measureRunnersGaps(WidgetTester tester) {
  final Rect summary = tester.getRect(find.text(_runnersSummary));
  final Rect list = tester.getRect(find.byType(ResponsiveList));
  return <double>[_gapBetween(summary, list)];
}

List<double> _measureServerDownGaps(WidgetTester tester) {
  final Rect summary = tester.getRect(find.text(_serverDownSummary));
  final Rect banner = tester.getRect(find.byType(NoticeBanner));
  final Rect list = tester.getRect(find.byType(ResponsiveList));
  return <double>[_gapBetween(summary, banner), _gapBetween(banner, list)];
}

List<double> _measureAuditGaps(WidgetTester tester) {
  final Rect banner = tester.getRect(find.byType(NoticeBanner));
  final Rect list = tester.getRect(find.byType(ResponsiveList));
  return <double>[_gapBetween(banner, list)];
}

const List<_TabCase> _tabCases = <_TabCase>[
  _TabCase(
    tab: 'General',
    buildDependencies: buildGalleryDependencies,
    measureGaps: _measureGeneralGaps,
  ),
  _TabCase(
    tab: 'Runners',
    buildDependencies: buildGalleryDependencies,
    measureGaps: _measureRunnersGaps,
  ),
  _TabCase(
    tab: 'Runners',
    buildDependencies: buildDependenciesWithServerDown,
    measureGaps: _measureServerDownGaps,
  ),
  _TabCase(
    tab: 'Audit log',
    buildDependencies: buildGalleryDependencies,
    measureGaps: _measureAuditGaps,
  ),
];

Future<void> _openTab(
  WidgetTester tester, {
  required double width,
  required _TabCase tabCase,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpApp(
    tester,
    size: Size(width, desktopHeight),
    route: const SectionRoute(AppSection.settings),
    dependencies: tabCase.buildDependencies(),
  );
  await tapVisible(tester, find.text(tabCase.tab));
  await pumpFrames(tester);
}

void _expectBodyMuted(WidgetTester tester, Finder text) {
  final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(text);
  final TextStyle shownStyle = paragraph.text.style!;
  expect(shownStyle.fontSize, AppFontSizes.body, reason: '$text');
  expect(shownStyle.color, AppColors.inkMuted, reason: '$text');
}

void main() {
  testWidgets('test_workspace_settings_screen_property_blocks_use_page_gap', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(7921);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = randomWidth(
        random,
        least: narrowestWidth,
        most: widestWidth,
      );
      final _TabCase tabCase = pickOne(random, _tabCases);
      await _openTab(tester, width: width, tabCase: tabCase);

      for (final double gap in tabCase.measureGaps(tester)) {
        final String reason = '${tabCase.tab} at width $width';
        expect(gap, closeTo(_expectedPageGap(width), 0.5), reason: reason);
      }
    }
  });

  testWidgets('test_settings_tabs_property_muted_paragraphs_use_body_text', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(7922);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = randomWidth(
        random,
        least: narrowestWidth,
        most: widestWidth,
      );
      await _openTab(tester, width: width, tabCase: _tabCases[0]);
      _expectBodyMuted(tester, find.textContaining('Removing a device here'));
      _expectBodyMuted(tester, find.text('Your devices'));

      await _openTab(tester, width: width, tabCase: _tabCases[2]);
      _expectBodyMuted(tester, find.text(_serverDownSummary));
      _expectBodyMuted(tester, find.textContaining('Last connected 14:12'));

      await _openTab(tester, width: width, tabCase: _tabCases[3]);
      _expectBodyMuted(tester, find.textContaining('Latest '));
      _expectBodyMuted(tester, find.text('14:09'));
    }
  });
}
