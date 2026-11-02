import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_pairing.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_typography.dart';

import '../support/app_harness.dart';

const Map<String, AppRoute> _setupTextOpenings = <String, AppRoute>{
  'The role is part of': SetupRoleRoute(),
  'On a device you already use': PairingCodeEntryRoute(DeviceRole.client),
};

bool _isTextStarting(Widget widget, String opening) {
  return widget is RichText && widget.text.toPlainText().startsWith(opening);
}

TextStyle _styleOfTextStarting(WidgetTester tester, String opening) {
  final Finder paragraph = find.byWidgetPredicate(
    (Widget widget) => _isTextStarting(widget, opening),
  );
  return tester.widget<RichText>(paragraph).text.style!;
}

void _expectSetupText(TextStyle style, String reason) {
  expect(style.fontSize, AppFontSizes.body, reason: reason);
  expect(style.color, AppColors.inkMuted, reason: reason);
}

void main() {
  testWidgets('test_setup_panel_property_setup_text_is_muted_body_text', (
    WidgetTester tester,
  ) async {
    final Map<String, AppRoute> openings = <String, AppRoute>{
      ..._setupTextOpenings,
      'It starts when you log in': PairingDoneRoute(galleryPairingOutcome),
    };

    for (final MapEntry<String, AppRoute> opening in openings.entries) {
      for (final Size size in <Size>[phoneSize, desktopSize]) {
        await pumpApp(
          tester,
          size: size,
          route: opening.value,
          dependencies: buildGalleryDependencies(),
        );

        final TextStyle style = _styleOfTextStarting(tester, opening.key);
        _expectSetupText(style, '${opening.key} at $size');
      }
    }
  });

  testWidgets('test_pairing_code_entry_property_code_uses_design_tracking', (
    WidgetTester tester,
  ) async {
    for (final Size size in <Size>[phoneSize, desktopSize]) {
      await pumpApp(
        tester,
        size: size,
        route: const PairingCodeEntryRoute(DeviceRole.client),
        dependencies: buildGalleryDependencies(),
      );

      final TextStyle codeStyle = tester
          .widget<TextField>(find.byType(TextField))
          .style!;
      final double trackingEm = codeStyle.letterSpacing! / codeStyle.fontSize!;
      expect(trackingEm, closeTo(AppTracking.codeEm, 0.0001), reason: '$size');
    }
  });
}
