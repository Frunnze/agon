import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_runners.dart';
import 'package:agent_orchestration/data/models/agent_login.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/presentation/agent_login_text.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../support/app_harness.dart';
import '../support/form_finders.dart';
import '../support/random_inputs.dart';
import '../support/sample_runners.dart';

const DeviceId _thisDeviceId = GalleryDeviceIds.airLaptop;

AgentLoginStatus _randomStatus(Random random) {
  return AgentLoginStatus(
    claudeLogin: pickOne(random, ClaudeLogin.values),
    containerCredential: random.nextBool()
        ? null
        : pickOne(random, AgentCredentialKind.values),
  );
}

Future<FakeAgentLoginRepository> _openRunnerPage(
  WidgetTester tester, {
  required DeviceId runnerId,
  required AgentPlace place,
  required AgentLoginStatus status,
}) async {
  final FakeAgentLoginRepository logins = FakeAgentLoginRepository(
    status: status,
  );
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpApp(
    tester,
    size: desktopSize,
    route: RunnerDetailRoute(runnerId),
    dependencies: replaceRepositories(
      buildGalleryDependencies(),
      deviceRepository: FakeDeviceRepository(
        devices: galleryDevices,
        currentDeviceId: _thisDeviceId,
        peerAddressProblem: null,
      ),
      runnerRepository: FakeRunnerRepository(
        runners: <Runner>[
          ...galleryRunners,
          buildOnlineRunnerOn(_thisDeviceId),
        ],
        thisDeviceOffers: <PlaceOffer>[
          PlaceOffer(place: place, problem: null),
        ],
        thisRunnerProblem: null,
      ),
      agentLoginRepository: logins,
    ),
  );
  return logins;
}

Future<void> _tapLabel(WidgetTester tester, String label) async {
  await tapVisible(tester, find.text(label));
  await pumpFrames(tester);
}

void main() {
  testWidgets('test_agent_login_section_property_matches_the_status', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9401);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AgentPlace place = pickOne(random, AgentPlace.values);
      final AgentLoginStatus status = _randomStatus(random);

      await _openRunnerPage(
        tester,
        runnerId: _thisDeviceId,
        place: place,
        status: status,
      );

      final AgentLoginDescription description = describeAgentLogin(
        place: place,
        status: status,
      );
      expect(find.text(describeAgentLoginTitle(place)), findsOneWidget);
      expect(find.text(description.statusText), findsOneWidget);
      expect(find.text(description.detail), findsOneWidget);
      final List<AgentLoginAction> actions = chooseAgentLoginActions(
        place: place,
        status: status,
      );
      for (final AgentLoginAction action in AgentLoginAction.values) {
        final Matcher shown = actions.contains(action)
            ? findsOneWidget
            : findsNothing;
        expect(find.text(describeAgentLoginAction(action)), shown);
      }
    }
  });

  testWidgets('test_agent_login_section_property_only_on_this_computer', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9402);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final bool isThisDevice = random.nextBool();
      final AgentPlace place = pickOne(random, AgentPlace.values);

      await _openRunnerPage(
        tester,
        runnerId: isThisDevice ? _thisDeviceId : galleryRunners.first.deviceId,
        place: place,
        status: _randomStatus(random),
      );

      final Matcher shown = isThisDevice ? findsOneWidget : findsNothing;
      expect(find.text(describeAgentLoginTitle(place)), shown);
    }
  });

  testWidgets('test_log_in_property_typed_keys_reach_the_terminal', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9403);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String code = 'code-${random.nextInt(100000)}';
      await _openRunnerPage(
        tester,
        runnerId: _thisDeviceId,
        place: AgentPlace.localProcess,
        status: const AgentLoginStatus(
          claudeLogin: ClaudeLogin.notLoggedIn,
          containerCredential: null,
        ),
      );

      await _tapLabel(tester, logInLabel);
      expect(find.textContaining('claude auth login'), findsOneWidget);
      await tester.enterText(find.byType(TextField), code);
      await _tapLabel(tester, sendLabel);

      expect(find.textContaining(code), findsOneWidget);
      await _tapLabel(tester, closeLabel);
      expect(find.textContaining('claude auth login'), findsNothing);
      expect(find.text(logInLabel), findsOneWidget);
    }
  });

  testWidgets('test_connect_property_a_finished_login_shows_connected', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9404);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FakeAgentLoginRepository logins = await _openRunnerPage(
        tester,
        runnerId: _thisDeviceId,
        place: AgentPlace.container,
        status: AgentLoginStatus(
          claudeLogin: pickOne(random, <ClaudeLogin>[
            ClaudeLogin.loggedIn,
            ClaudeLogin.notLoggedIn,
          ]),
          containerCredential: null,
        ),
      );

      await _tapLabel(tester, connectClaudeCodeLabel);
      expect(find.textContaining('claude setup-token'), findsOneWidget);
      logins.endTerminal(problem: null);
      await pumpFrames(tester);

      expect(find.textContaining('claude setup-token'), findsNothing);
      expect(find.text(connectedText), findsOneWidget);
      expect(find.text(disconnectLabel), findsOneWidget);
    }
  });

  testWidgets('test_connect_property_a_failed_login_shows_the_problem', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9405);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String problem = 'stopped ${random.nextInt(1000)}';
      final FakeAgentLoginRepository logins = await _openRunnerPage(
        tester,
        runnerId: _thisDeviceId,
        place: AgentPlace.container,
        status: const AgentLoginStatus(
          claudeLogin: ClaudeLogin.loggedIn,
          containerCredential: null,
        ),
      );

      await _tapLabel(tester, connectClaudeCodeLabel);
      logins.endTerminal(problem: problem);
      await pumpFrames(tester);

      expect(find.textContaining(problem), findsOneWidget);
      expect(find.text(sendLabel), findsNothing);
      await _tapLabel(tester, closeLabel);
      expect(find.textContaining(problem), findsNothing);
    }
  });

  testWidgets('test_api_key_property_a_saved_key_connects_containers', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9406);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String apiKey = 'sk-ant-api03-${random.nextInt(1 << 30)}';
      await _openRunnerPage(
        tester,
        runnerId: _thisDeviceId,
        place: AgentPlace.container,
        status: AgentLoginStatus(
          claudeLogin: pickOne(random, ClaudeLogin.values),
          containerCredential: null,
        ),
      );

      await _tapLabel(tester, useApiKeyLabel);
      expect(find.text(useApiKeyLabel), findsNothing);
      await enterFieldText(tester, label: apiKeyFieldLabel, text: apiKey);
      await _tapLabel(tester, saveKeyLabel);

      expect(find.text(connectedWithApiKeyText), findsOneWidget);
      expect(find.text(apiKeyFieldLabel), findsNothing);
      expect(find.text(apiKey), findsNothing);
    }
  });

  testWidgets('test_api_key_property_cancel_closes_the_field', (
    WidgetTester tester,
  ) async {
    await _openRunnerPage(
      tester,
      runnerId: _thisDeviceId,
      place: AgentPlace.container,
      status: const AgentLoginStatus(
        claudeLogin: ClaudeLogin.notInstalled,
        containerCredential: null,
      ),
    );

    await _tapLabel(tester, useApiKeyLabel);
    await _tapLabel(tester, cancelLabel);

    expect(find.text(apiKeyFieldLabel), findsNothing);
    expect(find.text(useApiKeyLabel), findsOneWidget);
  });

  testWidgets('test_disconnect_property_forgets_the_credential', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9407);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _openRunnerPage(
        tester,
        runnerId: _thisDeviceId,
        place: AgentPlace.container,
        status: AgentLoginStatus(
          claudeLogin: ClaudeLogin.loggedIn,
          containerCredential: pickOne(random, AgentCredentialKind.values),
        ),
      );

      await _tapLabel(tester, disconnectLabel);

      expect(find.text(notConnectedText), findsOneWidget);
      expect(find.text(connectClaudeCodeLabel), findsOneWidget);
    }
  });
}
