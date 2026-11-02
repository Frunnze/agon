import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/screens/projects.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../../support/app_harness.dart';
import '../../support/form_finders.dart';

const SectionRoute _projectsRoute = SectionRoute(AppSection.projects);

void main() {
  testWidgets('creating a project adds it with its repos', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    final AppNavigation navigation = await pumpApp(
      tester,
      size: desktopSize,
      route: _projectsRoute,
      dependencies: dependencies,
    );
    await tester.tap(find.text('New project'));
    await pumpFrames(tester);
    navigation.replaceRoute(NewItemFormRoute(DraftKind.project));
    await pumpFrames(tester);

    await tapVisible(tester, find.text('Create project'));
    await pumpFrames(tester);
    expect(find.text('Give it a name'), findsOneWidget);
    expect(find.text('Add at least one repo'), findsOneWidget);

    await enterFieldText(tester, label: 'Name', text: 'billing');
    await enterFieldText(tester, label: 'Repos', text: 'not an address');
    await tapVisible(tester, find.text('Add repo'));
    await pumpFrames(tester);
    expect(
      find.text('Paste an address like github.com/acme/repo'),
      findsOneWidget,
    );

    await enterFieldText(
      tester,
      label: 'Repos',
      text: 'https://github.com/acme/billing.git',
    );
    await tapVisible(tester, find.text('Add repo'));
    await pumpFrames(tester);
    expect(find.text('acme/billing'), findsOneWidget);
    expect(find.text('github.com · main'), findsOneWidget);

    await tapVisible(tester, find.text('Read only'));
    await tapVisible(tester, find.text('Create project'));
    await pumpFrames(tester);

    final AppRoute route = navigation.currentRoute;
    expect(route, isA<ProjectRoute>());
    final Project created = dependencies.projectRepository.findProject(
      (route as ProjectRoute).projectId,
    );
    expect(created.name, 'billing');
    expect(created.repositories.single.address, 'github.com/acme/billing');
    expect(created.repositories.single.agentAccess, AgentAccess.readOnly);
    expect(find.byType(ProjectScreen), findsOneWidget);
    expect(find.text('1 repo · 0 tasks'), findsOneWidget);
  });

  testWidgets('adding and removing a repo updates the project page', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    await pumpApp(
      tester,
      size: phoneSize,
      route: const ProjectRoute(GalleryProjectIds.mlRanker),
      dependencies: dependencies,
    );

    await tester.tap(find.text('Add repo').first);
    await pumpFrames(tester);
    await enterFieldText(
      tester,
      label: 'Address',
      text: 'github.com/acme/web',
    );
    await tapVisible(tester, find.text('Add repo').last);
    await pumpFrames(tester);

    expect(find.text('acme/web'), findsOneWidget);
    expect(find.text('2 repos · 0 tasks'), findsOneWidget);

    await tapVisible(tester, find.text('Remove').first);
    await pumpFrames(tester);
    await tapVisible(tester, find.text('Remove repo'));
    await pumpFrames(tester);

    expect(find.text('acme/ranker'), findsNothing);
    expect(
      dependencies.projectRepository
          .findProject(GalleryProjectIds.mlRanker)
          .repositories
          .single
          .address,
      'github.com/acme/web',
    );
  });

  testWidgets('add rule opens the rule form for this project', (
    WidgetTester tester,
  ) async {
    final AppNavigation navigation = await pumpApp(
      tester,
      size: desktopSize,
      route: const ProjectRoute(GalleryProjectIds.acmeApp),
      dependencies: buildGalleryDependencies(),
    );

    await tapVisible(tester, find.text('Add rule'));
    await pumpFrames(tester);

    expect(
      navigation.currentRoute,
      const NewRuleRoute(presetProjectId: GalleryProjectIds.acmeApp),
    );
  });
}
