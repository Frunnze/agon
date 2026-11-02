import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_pairing.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/data/repository/pairing_repository.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../support/app_harness.dart';
import '../support/form_finders.dart';
import '../support/random_inputs.dart';

const List<String> _wordChoices = <String>[
  'amber',
  'cedar',
  'lunar',
  'oak',
  'river',
  'quartz',
  'maple',
  'frost',
];
const int _wordCount = 4;

final TargetPlatformVariant _onMac = TargetPlatformVariant.only(
  TargetPlatform.macOS,
);

final class _WaitingPairingRepository extends ChangeNotifier
    implements PairingRepository {
  _WaitingPairingRepository({required this.words});

  final List<String> words;
  final Completer<PairingOutcome> approval = Completer<PairingOutcome>();
  WaitingJoin? _waitingJoin;

  @override
  WaitingJoin? findWaitingJoin() => _waitingJoin;

  @override
  Future<PairingOutcome> joinWithCode({
    required String? serverAddress,
    required String code,
    required String deviceName,
    required DeviceRole role,
  }) async {
    _waitingJoin = WaitingJoin(code: code, fingerprintWords: words);
    notifyListeners();
    final PairingOutcome outcome = await approval.future;
    _waitingJoin = null;
    notifyListeners();
    return outcome;
  }

  @override
  PairingSession? findActiveSession() => null;

  @override
  PairingRequest? findPendingRequest() => null;

  @override
  Future<PairingSession> startPairing() => throw UnimplementedError();

  @override
  Future<Device> approvePairing(List<WorkspaceId> workspaces) {
    throw UnimplementedError();
  }

  @override
  Future<void> rejectPairing() => throw UnimplementedError();

  @override
  Future<void> cancelPairing() => throw UnimplementedError();

  @override
  Future<PairingOutcome> createHostedAccount({
    required String workspaceName,
    required String deviceName,
    required DeviceRole role,
  }) {
    throw UnimplementedError();
  }
}

List<String> _randomWords(Random random) {
  final List<String> shuffled = <String>[..._wordChoices]..shuffle(random);
  return shuffled.sublist(0, _wordCount);
}

void main() {
  testWidgets('test_join_with_code_property_waiting_screen_shows_words', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10031);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<String> words = _randomWords(random);
      final _WaitingPairingRepository repository = _WaitingPairingRepository(
        words: words,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      final AppNavigation navigation = await pumpApp(
        tester,
        size: desktopSize,
        route: const PairingCodeEntryRoute(DeviceRole.client),
        dependencies: replaceRepositories(
          buildGalleryDependencies(),
          pairingRepository: repository,
        ),
      );

      await enterFieldText(tester, label: 'Pairing code', text: '4F7-K2Q');
      await tapVisible(tester, find.text('Pair this Mac'));
      await pumpFrames(tester);

      for (final String word in words) {
        expect(find.text(word), findsOneWidget);
      }
      expect(navigation.currentRoute is PairingDoneRoute, isFalse);

      repository.approval.complete(galleryPairingOutcome);
      await pumpFrames(tester);
      expect(navigation.currentRoute is PairingDoneRoute, isTrue);
    }
  }, variant: _onMac);
}
