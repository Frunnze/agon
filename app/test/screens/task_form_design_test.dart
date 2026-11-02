import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';

import '../support/app_harness.dart';

const double _lineHeight = AppFontSizes.body * AppLineHeights.body;
const double _fieldFrame = 2 * (AppSpacing.space2 + AppBorders.thin);
const int _detailsRows = 3;

bool _isDetailsField(Widget widget) {
  return widget is TextField && widget.minLines == _detailsRows;
}

void main() {
  testWidgets('test_task_form_property_details_field_follows_design_rows', (
    WidgetTester tester,
  ) async {
    const List<AppRoute> formRoutes = <AppRoute>[
      EditTaskRoute(GalleryTaskIds.cleanUpBranches),
      EditJobRoute(GalleryTaskIds.updateDependencies),
    ];

    for (final AppRoute route in formRoutes) {
      for (final Size size in <Size>[phoneSize, desktopSize]) {
        await pumpApp(
          tester,
          size: size,
          route: route,
          dependencies: buildGalleryDependencies(),
        );

        final double height = tester
            .getSize(find.byWidgetPredicate(_isDetailsField))
            .height;
        final double textHeight = height - _fieldFrame;
        final String reason = '$route at $size';
        expect(textHeight % _lineHeight, 0, reason: reason);
        expect(
          textHeight >= _detailsRows * _lineHeight,
          isTrue,
          reason: reason,
        );
      }
    }
  });
}
