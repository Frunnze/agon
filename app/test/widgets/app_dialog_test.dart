import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_theme.dart';
import 'package:agent_orchestration/theme/layout_size.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/app_dialog.dart';

import '../support/random_inputs.dart';
import '../support/widget_harness.dart';

Widget buildDialogLauncher(void Function(String?) onClosed) {
  return MaterialApp(
    theme: buildAppTheme(),
    home: Builder(builder: (BuildContext context) => _Launcher(onClosed)),
  );
}

class _Launcher extends StatelessWidget {
  const _Launcher(this.onClosed);

  final void Function(String?) onClosed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppButton.primary(label: 'Open', onPressed: () => _open(context)),
    );
  }

  Future<void> _open(BuildContext context) async {
    final String? result = await showAppDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AppDialog(
        title: 'Approve push to GitHub?',
        content: const <Widget>[DialogNote('The hub makes the push.')],
        actions: <Widget>[
          AppButton.secondary(
            label: 'Deny',
            onPressed: () => Navigator.of(dialogContext).pop('denied'),
          ),
          AppButton.primary(
            label: 'Approve',
            onPressed: () => Navigator.of(dialogContext).pop('approved'),
          ),
        ],
      ),
    );
    onClosed(result);
  }
}

const List<String> _switcherActionLabels = <String>[
  'Close',
  'Your devices',
  'Create workspace',
];

Widget buildSwitcherActionsLauncher() {
  return MaterialApp(
    theme: buildAppTheme(),
    home: const Builder(builder: _buildSwitcherActionsPage),
  );
}

Widget _buildSwitcherActionsPage(BuildContext context) {
  return Scaffold(
    body: AppButton.primary(
      label: 'Open',
      onPressed: () => showAppDialog<void>(
        context: context,
        builder: _buildSwitcherActionsDialog,
      ),
    ),
  );
}

Widget _buildSwitcherActionsDialog(BuildContext context) {
  return AppDialog(
    title: 'Switch workspace',
    content: const <Widget>[DialogNote('Devices are paired once.')],
    actions: <Widget>[
      AppButton.secondary(label: _switcherActionLabels[0], onPressed: () {}),
      AppButton.secondary(
        label: _switcherActionLabels[1],
        icon: AppIconKind.key,
        onPressed: () {},
      ),
      AppButton.secondary(
        label: _switcherActionLabels[2],
        icon: AppIconKind.plus,
        onPressed: () {},
      ),
    ],
  );
}

void main() {
  testWidgets('test_show_app_dialog_property_sheet_on_phones_centred_wide', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(2501);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = randomWidth(random, least: 320, most: 1600);
      final Size size = Size(width, desktopHeight);
      String? closedWith;
      useViewSize(tester, size);
      await tester.pumpWidget(
        buildDialogLauncher((String? result) => closedWith = result),
      );
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final Rect panel = tester.getRect(find.byType(AppDialog));
      if (LayoutSize.forWidth(width).isCompact) {
        expect(panel.bottom, closeTo(size.height, 1));
        expect(panel.width, closeTo(width, 1));
      } else {
        expect(panel.center.dx, closeTo(width / 2, 1));
        expect(panel.width <= 512, isTrue);
      }
      expect(tester.takeException(), isNull);

      final String choice = random.nextBool() ? 'Deny' : 'Approve';
      await tester.tap(find.text(choice));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(closedWith, choice == 'Deny' ? 'denied' : 'approved');
    }
  });

  testWidgets('test_app_dialog_property_wide_actions_share_one_row', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(2502);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = randomWidth(random, least: 320, most: 1600);
      useViewSize(tester, Size(width, desktopHeight));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(buildSwitcherActionsLauncher());
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final Rect panel = tester.getRect(find.byType(AppDialog));
      final List<Rect> actions = <Rect>[
        for (final String label in _switcherActionLabels)
          tester.getRect(find.widgetWithText(AppButton, label)),
      ];
      final String reason = 'width $width';
      final double contentRight = panel.right - AppSpacing.space5;
      if (LayoutSize.forWidth(width).isCompact) {
        expect(actions.first.top > actions.last.top, isTrue, reason: reason);
        expect(actions.first.right, closeTo(contentRight, 0.5));
      } else {
        for (final Rect action in actions) {
          expect(action.top, closeTo(actions.first.top, 0.5), reason: reason);
        }
        expect(actions.last.right, closeTo(contentRight, 0.5));
      }
      expect(tester.takeException(), isNull, reason: reason);
    }
  });
}
