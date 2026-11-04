import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_audit.dart';
import 'package:agent_orchestration/data/gallery/gallery_chat.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_library.dart';
import 'package:agent_orchestration/data/gallery/gallery_runners.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/audit.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/presentation/runner_text.dart';
import 'package:agent_orchestration/screens/projects.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../support/app_harness.dart';
import '../support/form_finders.dart';
import '../support/list_harness.dart';
import '../support/random_inputs.dart';

const String _auditMessage =
    'Pairings, signed workflows and other changes show up here, each signed '
    'by the device that made it.';
const String _repositoriesMessage =
    "Add a repo so this project's tasks have code to work on.";
const String _tokenNote =
    'Each run gets its own short-lived token for these repos. The token '
    'stops working when the run ends.';
const String _projectRulesNote = 'No rules apply to this project yet.';
const String _chatMessage =
    "The agent's replies and the commands it runs show up here as it works.";
const List<Size> _sizes = <Size>[phoneSize, desktopSize];
const ProjectRoute _acmeAppRoute = ProjectRoute(GalleryProjectIds.acmeApp);
const ChatRoute _chatRoute = ChatRoute(GalleryRunIds.release42);

Project _findAcmeApp() {
  for (final Project project in galleryProjects) {
    if (project.id == GalleryProjectIds.acmeApp) {
      return project;
    }
  }
  throw StateError('the gallery has no acme-app project');
}

void main() {
  testWidgets(
    'test_devices_screen_property_runner_summary_only_with_runners',
    (WidgetTester tester) async {
      final Random random = seededRandom(7201);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final List<Runner> runners = pickRandomRecords(random, galleryRunners);
        await pumpApp(
          tester,
          size: pickOne(random, _sizes),
          route: const SectionRoute(AppSection.devices),
          dependencies: buildDependenciesWithRunners(runners),
        );

        expect(
          find.text('Runners: ${describeRunnerFleet(runners)}'),
          runners.isNotEmpty ? findsOneWidget : findsNothing,
        );
        expect(find.text('No runners yet'), findsNothing);
      }
    },
  );

  testWidgets('test_audit_log_tab_property_empty_only_without_entries', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(7202);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<AuditEntry> entries = pickRandomRecords(
        random,
        galleryAuditEntries,
      );
      await pumpApp(
        tester,
        size: pickOne(random, _sizes),
        route: const SectionRoute(AppSection.settings),
        dependencies: buildDependenciesWithAuditEntries(entries),
      );
      await tapVisible(tester, find.text('Audit log'));
      await pumpFrames(tester);

      expect(
        find.text('Nothing logged yet'),
        entries.isEmpty ? findsOneWidget : findsNothing,
      );
      expect(
        find.text(_auditMessage),
        entries.isEmpty ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('The log is intact'),
        entries.isNotEmpty ? findsOneWidget : findsNothing,
      );
    }
  });

  testWidgets('test_project_screen_property_empty_only_without_repositories', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(7203);
    final Project acmeApp = _findAcmeApp();

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Repository> repositories = pickRandomRecords(
        random,
        acmeApp.repositories,
      );
      await pumpApp(
        tester,
        size: pickOne(random, _sizes),
        route: _acmeAppRoute,
        dependencies: buildDependenciesWithRepositories(
          projectId: acmeApp.id,
          repositories: repositories,
        ),
      );

      final bool isEmpty = repositories.isEmpty;
      expect(
        find.text('No repos yet'),
        isEmpty ? findsOneWidget : findsNothing,
      );
      expect(
        find.text(_repositoriesMessage),
        isEmpty ? findsOneWidget : findsNothing,
      );
      expect(find.text(_tokenNote), isEmpty ? findsNothing : findsOneWidget);
      expect(find.text('Add repo'), findsOneWidget);
    }
  });

  testWidgets('test_project_rules_section_property_note_only_without_rules', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(7204);
    final Project acmeApp = _findAcmeApp();

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Rule> rules = pickRandomRecords(random, galleryRules);
      final List<Rule> projectRules = findProjectRules(rules, acmeApp);
      await pumpApp(
        tester,
        size: pickOne(random, _sizes),
        route: _acmeAppRoute,
        dependencies: buildDependenciesWithRules(rules),
      );

      expect(
        find.text(_projectRulesNote),
        projectRules.isEmpty ? findsOneWidget : findsNothing,
      );
      expect(find.text('Add rule'), findsOneWidget);
    }
  });

  testWidgets('test_conversation_view_property_empty_only_without_messages', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(7205);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<ChatMessage> messages = pickRandomRecords(
        random,
        galleryRunChat,
      );
      await pumpApp(
        tester,
        size: pickOne(random, _sizes),
        route: _chatRoute,
        dependencies: buildDependenciesWithChatMessages(messages),
      );

      expect(
        find.text('No messages yet'),
        messages.isEmpty ? findsOneWidget : findsNothing,
      );
      expect(
        find.text(_chatMessage),
        messages.isEmpty ? findsOneWidget : findsNothing,
      );
      expect(find.text('Send'), findsOneWidget);
    }
  });
}
