import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/app.dart';
import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/product_name.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/shell/app_shell.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/theme/dense_text_scaler.dart';
import 'package:agent_orchestration/theme/field_padding.dart';
import 'package:agent_orchestration/theme/layout_density.dart';
import 'package:agent_orchestration/windows/run_window_opener.dart';

import 'support/app_harness.dart';
import 'support/random_inputs.dart';
import 'support/widget_harness.dart';

const double _lowestHeight = 600;
const double _smallestTextScale = 0.8;
const double _largestTextScale = 2;

final class _SilentRunWindowOpener implements RunWindowOpener {
  @override
  void openRunWindow({required RunId runId, required String title}) {}
}

final class _PumpedApp {
  const _PumpedApp({
    required this.dependencies,
    required this.navigation,
    required this.messengerKey,
    required this.runWindowOpener,
  });

  final AppDependencies dependencies;
  final AppNavigation navigation;
  final GlobalKey<ScaffoldMessengerState> messengerKey;
  final RunWindowOpener? runWindowOpener;
}

Size _randomWindowSize(Random random) {
  final double width = randomWidth(
    random,
    least: narrowestWidth,
    most: widestWidth,
  );
  final double height = randomWidth(
    random,
    least: _lowestHeight,
    most: desktopHeight,
  );
  return Size(width, height);
}

Future<_PumpedApp> _pumpRandomApp(WidgetTester tester, Random random) async {
  final AppSection section = pickOne(random, AppSection.values);
  RunWindowOpener? runWindowOpener;
  if (random.nextBool()) {
    runWindowOpener = _SilentRunWindowOpener();
  }
  final _PumpedApp app = _PumpedApp(
    dependencies: buildGalleryDependencies(),
    navigation: AppNavigation(initialRoute: SectionRoute(section)),
    messengerKey: GlobalKey<ScaffoldMessengerState>(),
    runWindowOpener: runWindowOpener,
  );

  useViewSize(tester, _randomWindowSize(random));
  await tester.pumpWidget(
    AgentOrchestrationApp(
      dependencies: app.dependencies,
      navigation: app.navigation,
      messengerKey: app.messengerKey,
      runWindowOpener: app.runWindowOpener,
    ),
  );
  await tester.pump();
  await tester.pump(settleTime);
  return app;
}

void main() {
  testWidgets(
    'test_agent_orchestration_app_build_property_shell_gets_its_inputs',
    (WidgetTester tester) async {
      final Random random = seededRandom(48601);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final _PumpedApp app = await _pumpRandomApp(tester, random);

        final AppShell shell = tester.widget<AppShell>(find.byType(AppShell));
        final MaterialApp materialApp = tester.widget<MaterialApp>(
          find.byType(MaterialApp),
        );
        expect(tester.takeException(), isNull);
        expect(identical(shell.dependencies, app.dependencies), isTrue);
        expect(identical(shell.navigation, app.navigation), isTrue);
        expect(identical(shell.runWindowOpener, app.runWindowOpener), isTrue);
        expect(materialApp.title, productName);
        expect(find.byType(CheckedModeBanner), findsNothing);
      }
    },
  );

  testWidgets(
    'test_agent_orchestration_app_build_property_messenger_key_shows_notes',
    (WidgetTester tester) async {
      final Random random = seededRandom(48602);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final _PumpedApp app = await _pumpRandomApp(tester, random);
        final String note = 'Note $i ${randomWordPhrase(random)}'.trim();

        final ScaffoldMessengerState? messenger =
            app.messengerKey.currentState;
        if (messenger == null) {
          fail('the messenger key reaches no messenger');
        }
        messenger.showSnackBar(SnackBar(content: Text(note)));
        await tester.pump();
        await tester.pump(settleTime);

        expect(find.text(note), findsOneWidget);
        messenger.removeCurrentSnackBar();
        await tester.pump();
      }
    },
  );

  testWidgets(
    'test_agent_orchestration_app_build_property_density_follows_platform',
    (WidgetTester tester) async {
      final TargetPlatform platform = defaultTargetPlatform;
      final LayoutDensity expectedDensity = LayoutDensity.forPlatform(
        platform,
      );
      final Random random = seededRandom(48603 + platform.index);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final double platformTextScale = randomWidth(
          random,
          least: _smallestTextScale,
          most: _largestTextScale,
        );
        tester.platformDispatcher.textScaleFactorTestValue = platformTextScale;
        await _pumpRandomApp(tester, random);

        final BuildContext shellContext = tester.element(
          find.byType(AppShell),
        );
        final TextScaler expectedTextScaler = textScalerFor(
          layoutDensity: expectedDensity,
          platformTextScaler: TextScaler.linear(platformTextScale),
        );
        final double shownBodySize = MediaQuery.textScalerOf(shellContext)
            .scale(AppFontSizes.body);
        expect(LayoutDensity.of(shellContext), expectedDensity);
        expect(
          shownBodySize,
          moreOrLessEquals(expectedTextScaler.scale(AppFontSizes.body)),
        );
        expect(
          Theme.of(shellContext).inputDecorationTheme.contentPadding,
          singleLineFieldPaddingFor(expectedDensity),
        );
      }
    },
    variant: TargetPlatformVariant.all(),
  );
}
