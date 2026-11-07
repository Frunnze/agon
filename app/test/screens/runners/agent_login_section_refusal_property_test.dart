import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_runners.dart';
import 'package:agent_orchestration/data/models/agent_login.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/presentation/agent_login_text.dart';
import 'package:agent_orchestration/screens/runners/api_key_form.dart';
import 'package:agent_orchestration/screens/runners/login_terminal_panel.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/app_harness.dart';
import '../../support/runner_pages.dart';
import '../../support/sample_runners.dart';
import '../support/planned_refusal.dart';
import '../support/refused_action_properties.dart';
import '../support/refusing_work_repositories.dart';

const String _typedApiKey = 'sk-ant-test-key';
const String _typedTerminalKeys = 'pasted code';

typedef _PreparePage = Future<void> Function(WidgetTester tester);

final class _LoginPage {
  _LoginPage({required this.place, required this.status});

  final AgentPlace place;
  final AgentLoginStatus status;
  late RefusingAgentLoginRepository logins;

  Future<void> open(
    WidgetTester tester, {
    required Size size,
    required PlannedRefusal refusal,
  }) async {
    logins = RefusingAgentLoginRepository(
      stored: FakeAgentLoginRepository(status: status),
      refusal: refusal,
    );
    await pumpApp(
      tester,
      size: size,
      route: const RunnerDetailRoute(thisRunnerDeviceId),
      dependencies: replaceRepositories(
        buildGalleryDependencies(),
        deviceRepository: buildRunnerDevices(peerAddressProblem: null),
        runnerRepository: buildOfferingRunners(
          runners: <Runner>[
            ...galleryRunners,
            buildOnlineRunnerOn(thisRunnerDeviceId),
          ],
          offers: <PlaceOffer>[PlaceOffer(place: place, problem: null)],
          problem: null,
        ),
        agentLoginRepository: logins,
      ),
    );
  }

  Future<void> openTerminalFirst(WidgetTester tester) async {
    await logins.stored.openTerminal(place);
    await pumpFrames(tester);
  }

  Future<void> openApiKeyFormFirst(WidgetTester tester) {
    return tapButtonLabelled(tester, useApiKeyLabel);
  }
}

Future<void> _enterText(WidgetTester tester, Type form, String text) async {
  final Finder field = find.descendant(
    of: find.byType(form),
    matching: find.byType(TextField),
  );
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pump();
}

RefusedActionCase _buildLoginCase({
  required String functionName,
  required String actionLabel,
  required _LoginPage page,
  required _PreparePage? preparePage,
  required _PreparePage performAction,
  required ExpectActionSucceeded expectSucceeded,
}) {
  return RefusedActionCase(
    functionName: functionName,
    actionLabel: actionLabel,
    place: RefusalPlace.dialogOverPage,
    openPage: (tester, {required size, required refusal}) async {
      await page.open(tester, size: size, refusal: refusal);
      await preparePage?.call(tester);
    },
    performAction: performAction,
    expectSucceeded: expectSucceeded,
  );
}

List<RefusedActionCase> _buildLoginCases() {
  final _LoginPage notLoggedIn = _LoginPage(
    place: AgentPlace.localProcess,
    status: const AgentLoginStatus(
      claudeLogin: ClaudeLogin.notLoggedIn,
      containerCredential: null,
    ),
  );
  final _LoginPage connectedDocker = _LoginPage(
    place: AgentPlace.container,
    status: const AgentLoginStatus(
      claudeLogin: ClaudeLogin.loggedIn,
      containerCredential: AgentCredentialKind.longLivedToken,
    ),
  );
  final _LoginPage keylessDocker = _LoginPage(
    place: AgentPlace.container,
    status: const AgentLoginStatus(
      claudeLogin: ClaudeLogin.notInstalled,
      containerCredential: null,
    ),
  );
  final _LoginPage typingTerminal = _LoginPage(
    place: AgentPlace.localProcess,
    status: notLoggedIn.status,
  );
  final _LoginPage closingTerminal = _LoginPage(
    place: AgentPlace.localProcess,
    status: notLoggedIn.status,
  );

  return <RefusedActionCase>[
    _buildLoginCase(
      functionName: 'open_terminal',
      actionLabel: logInLabel,
      page: notLoggedIn,
      preparePage: null,
      performAction: (tester) => tapButtonLabelled(tester, logInLabel),
      expectSucceeded: (tester) {
        expect(notLoggedIn.logins.findTerminal(), isNotNull);
        expect(find.byType(LoginTerminalPanel), findsOneWidget);
      },
    ),
    _buildLoginCase(
      functionName: 'forget_credential',
      actionLabel: disconnectLabel,
      page: connectedDocker,
      preparePage: null,
      performAction: (tester) => tapButtonLabelled(tester, disconnectLabel),
      expectSucceeded: (tester) {
        final AgentLoginStatus? status = connectedDocker.logins.findStatus();
        expect(status?.containerCredential, isNull);
      },
    ),
    _buildLoginCase(
      functionName: 'save_api_key',
      actionLabel: saveKeyLabel,
      page: keylessDocker,
      preparePage: keylessDocker.openApiKeyFormFirst,
      performAction: (tester) async {
        await _enterText(tester, ApiKeyForm, _typedApiKey);
        await tapButtonLabelled(tester, saveKeyLabel);
      },
      expectSucceeded: (tester) {
        final AgentLoginStatus? status = keylessDocker.logins.findStatus();
        expect(status?.containerCredential, AgentCredentialKind.apiKey);
        expect(find.byType(ApiKeyForm), findsNothing);
      },
    ),
    _buildLoginCase(
      functionName: 'type_into_terminal',
      actionLabel: sendLabel,
      page: typingTerminal,
      preparePage: typingTerminal.openTerminalFirst,
      performAction: (tester) async {
        await _enterText(tester, LoginTerminalPanel, _typedTerminalKeys);
        await tapButtonLabelled(tester, sendLabel);
      },
      expectSucceeded: (tester) {
        final LoginTerminal? terminal = typingTerminal.logins.findTerminal();
        expect(terminal?.lines, contains(_typedTerminalKeys));
      },
    ),
    _buildLoginCase(
      functionName: 'close_terminal',
      actionLabel: closeLabel,
      page: closingTerminal,
      preparePage: closingTerminal.openTerminalFirst,
      performAction: (tester) => tapButtonLabelled(tester, closeLabel),
      expectSucceeded: (tester) {
        expect(closingTerminal.logins.findTerminal(), isNull);
        expect(find.byType(LoginTerminalPanel), findsNothing);
      },
    ),
  ];
}

void main() {
  int seed = 91401;
  for (final RefusedActionCase actionCase in _buildLoginCases()) {
    registerRefusedActionProperties(actionCase, seed: seed);
    seed += 10;
  }
}
