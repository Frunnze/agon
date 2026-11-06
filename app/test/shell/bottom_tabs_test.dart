import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/icons/app_icon.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/shell/bottom_tabs.dart';
import 'package:agent_orchestration/theme/layout_size.dart';
import 'package:agent_orchestration/widgets/count_badge.dart';

import '../support/random_inputs.dart';
import '../support/widget_harness.dart';

const double _widestCompactWidth = 767;
const int _largestSingleDigitCount = 9;
const double _badgeWidthSlack = 2;

Future<void> _pumpBottomTabs(
  WidgetTester tester, {
  required double width,
  required TargetPlatform platform,
  required int pendingApprovalCount,
}) async {
  final Widget bottomTabs = BottomTabs(
    currentSection: AppSection.tasks,
    pendingApprovalCount: pendingApprovalCount,
    onSectionSelected: (AppSection section) {},
  );
  final Widget pinnedToBottom = Align(
    alignment: Alignment.bottomCenter,
    child: bottomTabs,
  );

  useViewSize(tester, Size(width, phoneHeight));
  await tester.pumpWidget(wrapInApp(pinnedToBottom, platform: platform));
}

Finder _findApprovalsIcon() {
  final Finder approvalsTab = find.ancestor(
    of: find.byType(CountBadge),
    matching: find.byType(InkWell),
  );

  return find.descendant(of: approvalsTab, matching: find.byType(AppIcon));
}

void main() {
  testWidgets('test_bottom_tabs_property_badge_hugs_the_icon_corner', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(3201);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = randomWidth(
        random,
        least: narrowestWidth,
        most: _widestCompactWidth,
      );
      final int pendingApprovalCount =
          1 + random.nextInt(_largestSingleDigitCount);
      final TargetPlatform platform = pickOne(random, <TargetPlatform>[
        phonePlatform,
        desktopPlatform,
      ]);
      expect(LayoutSize.forWidth(width).isCompact, isTrue);

      await _pumpBottomTabs(
        tester,
        width: width,
        platform: platform,
        pendingApprovalCount: pendingApprovalCount,
      );

      final Rect badgeArea = tester.getRect(find.byType(CountBadge));
      final Rect iconArea = tester.getRect(_findApprovalsIcon());
      final String reason = 'width $width count $pendingApprovalCount';
      expect(
        badgeArea.width,
        moreOrLessEquals(badgeArea.height, epsilon: _badgeWidthSlack),
        reason: reason,
      );
      expect(badgeArea.contains(iconArea.topRight), isTrue, reason: reason);
      expect(badgeArea.left, greaterThan(iconArea.center.dx), reason: reason);
      expect(badgeArea.top, lessThan(iconArea.top), reason: reason);
    }
  });
}
