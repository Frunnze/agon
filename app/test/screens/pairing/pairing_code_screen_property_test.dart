import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_pairing.dart';
import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/screens/pairing.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';

const Duration _pastExpiry = Duration(minutes: 6);
const String _freshFakeCode = '9QX-3MD';
const String _expiredCodeText = 'This code expired.';

String? _randomProblem(Random random) {
  if (random.nextBool()) {
    return null;
  }
  return '${randomWordPhrase(random)} ${randomText(random)}'.trim();
}

Size _randomWindowSize(Random random) {
  final double width = randomWidth(
    random,
    least: narrowestWidth,
    most: widestWidth,
  );
  return Size(width, pickOne(random, <double>[phoneHeight, desktopHeight]));
}

PairingSession _gallerySessionWith(String? problem) {
  return PairingSession(
    code: galleryPairingSession.code,
    createdAt: galleryPairingSession.createdAt,
    expiresAt: galleryPairingSession.expiresAt,
    rendezvousProblem: problem,
  );
}

AppDependencies _buildDependencies({
  required String? problem,
  required Duration elapsed,
}) {
  final AppDependencies base = buildGalleryDependencies();
  return replaceRepositories(
    base,
    pairingRepository: FakePairingRepository(
      session: _gallerySessionWith(problem),
      request: galleryPairingRequest,
      clock: FixedClock(galleryNow.add(elapsed)),
      deviceRepository: base.deviceRepository as FakeDeviceRepository,
      joinOutcome: galleryPairingOutcome,
    ),
  );
}

Future<void> _pumpCodeScreen(
  WidgetTester tester, {
  required Size size,
  required AppDependencies dependencies,
}) async {
  await pumpApp(
    tester,
    size: size,
    route: const PairingCodeRoute(),
    dependencies: dependencies,
  );
}

void main() {
  testWidgets('test_pairing_code_screen_build_property_'
      'shows_the_rendezvous_banner_only_with_a_problem', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(73801);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String? problem = _randomProblem(random);
      final Size size = _randomWindowSize(random);

      await _pumpCodeScreen(
        tester,
        size: size,
        dependencies: _buildDependencies(
          problem: problem,
          elapsed: Duration.zero,
        ),
      );

      final int expectedBanners = problem == null ? 0 : 1;
      expect(
        find.byType(RendezvousProblemBanner),
        findsNWidgets(expectedBanners),
        reason: 'size $size',
      );
      if (problem != null) {
        expect(find.text(problem), findsOneWidget, reason: 'size $size');
      }
      expect(tester.takeException(), isNull, reason: 'size $size');
    }
  });

  testWidgets('test_pairing_code_screen_build_property_'
      'banner_sits_above_a_still_usable_code', (WidgetTester tester) async {
    final Random random = seededRandom(73802);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Size size = _randomWindowSize(random);
      await _pumpCodeScreen(
        tester,
        size: size,
        dependencies: _buildDependencies(
          problem: randomText(random),
          elapsed: Duration.zero,
        ),
      );

      final Finder banner = find.byType(RendezvousProblemBanner);
      final Finder code = find.text(galleryPairingSession.code);
      final Finder qrCode = find.byType(PairingQrCode);

      expect(code, findsOneWidget, reason: 'size $size');
      expect(qrCode, findsOneWidget, reason: 'size $size');
      expect(
        tester.getRect(banner).bottom,
        lessThanOrEqualTo(tester.getRect(qrCode).top),
        reason: 'size $size',
      );
      expect(tester.takeException(), isNull, reason: 'size $size');
    }
  });

  testWidgets('test_pairing_code_screen_build_property_'
      'new_or_expired_code_drops_the_old_problem', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(73803);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final bool isExpired = random.nextBool();
      final Size size = _randomWindowSize(random);
      final AppDependencies dependencies = _buildDependencies(
        problem: randomText(random),
        elapsed: isExpired ? _pastExpiry : Duration.zero,
      );
      await _pumpCodeScreen(tester, size: size, dependencies: dependencies);

      if (isExpired) {
        expect(find.text(_expiredCodeText), findsOneWidget);
      } else {
        await dependencies.pairingRepository.startPairing();
        await pumpFrames(tester);
        expect(find.text(_freshFakeCode), findsOneWidget);
      }

      expect(find.byType(RendezvousProblemBanner), findsNothing);
      expect(tester.takeException(), isNull, reason: 'size $size');
    }
  });
}
