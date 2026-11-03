import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/shell/rail_workspace_header.dart';
import 'package:agent_orchestration/theme/layout_size.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../support/app_harness.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';

const String _tokenNote =
    'Each run gets its own short-lived token for these repos. The token '
    'stops working when the run ends.';
const String _switcherNote =
    'Each workspace has its own projects and picks which of your devices it '
    'uses. Devices are paired once for all of them.';
const SectionRoute _projectsRoute = SectionRoute(AppSection.projects);
const String _workspaceLinkText = 'acme workspace';
const List<String> _galleryProjectTexts = <String>[
  'Each project holds the repos its tasks work on.',
  'New project',
  'acme-app',
  'acme/app, acme/api',
  '2 repos',
  '4 tasks',
  '1 task running',
  'ml-ranker',
  'acme/ranker',
  'No runs yet',
  'acme/docs',
  'Ran yesterday',
];
const List<String> _switcherTexts = <String>[
  'Switch workspace',
  '3 projects · 4 runners',
  'Current',
  'personal',
  '1 project · 1 runner',
  'Open',
  _switcherNote,
  'Close',
  'Your devices',
  'Create workspace',
];
const List<String> _projectPageTexts = <String>[
  'acme-app',
  '2 repos · 4 tasks',
  'Browse files',
  'Add repo',
  'acme/app',
  'acme/api',
  'Read, push once approved',
  'Read only',
  _tokenNote,
  'Rules',
  'Add rule',
  'Never push to main',
  'Everywhere',
  'Ask before adding a dependency',
  'On',
  'Off',
];

void _expectTexts(List<String> texts) {
  for (final String text in texts) {
    expect(find.text(text), findsWidgets, reason: text);
  }
}

Finder _findWorkspaceOpener(Size size) {
  if (size == phoneSize) {
    return find.text(_workspaceLinkText);
  }
  return find.byType(RailWorkspaceHeader);
}

void main() {
  for (final Size size in <Size>[phoneSize, desktopSize]) {
    testWidgets('projects match the gallery at ${size.width}', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        size: size,
        route: _projectsRoute,
        dependencies: buildGalleryDependencies(),
      );

      _expectTexts(_galleryProjectTexts);
      expect(
        find.text('Activity'),
        size == desktopSize ? findsOne : findsNothing,
      );
    });

    testWidgets('workspace switcher matches the gallery at ${size.width}', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        size: size,
        route: _projectsRoute,
        dependencies: buildGalleryDependencies(),
      );
      await tester.tap(_findWorkspaceOpener(size));
      await pumpFrames(tester);

      _expectTexts(_switcherTexts);
    });

    testWidgets('project page matches the gallery at ${size.width}', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        size: size,
        route: const ProjectRoute(GalleryProjectIds.acmeApp),
        dependencies: buildGalleryDependencies(),
      );

      _expectTexts(_projectPageTexts);
      expect(find.text('Ship release 2.4'), findsNWidgets(2));
      expect(find.widgetWithText(AppButton, 'Remove'), findsNWidgets(2));
      expect(
        find.text('Agents can'),
        size == desktopSize ? findsOne : findsNothing,
      );
    });
  }

  testWidgets('switching workspace shows its projects', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    final AppNavigation navigation = await pumpApp(
      tester,
      size: desktopSize,
      route: _projectsRoute,
      dependencies: dependencies,
    );
    navigation.openRoute(const WorkspaceSwitcherRoute());
    await pumpFrames(tester);

    await tester.tap(find.text('personal'));
    await pumpFrames(tester);

    expect(
      dependencies.workspaceRepository.currentWorkspace().id,
      GalleryWorkspaceIds.personal,
    );
    expect(navigation.routes, <AppRoute>[_projectsRoute]);
    expect(find.text('blog'), findsOneWidget);
    expect(find.text('acme-app'), findsNothing);
  });

  testWidgets('creating a workspace switches to it', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    await pumpApp(
      tester,
      size: phoneSize,
      route: const WorkspaceSwitcherRoute(),
      dependencies: dependencies,
    );

    await tapVisible(tester, find.text('Create workspace'));
    await pumpFrames(tester);
    await enterFieldText(tester, label: 'Name', text: 'Bad Name');
    await tapVisible(tester, find.text('Create workspace').last);
    await pumpFrames(tester);
    expect(find.text('Use lowercase letters, digits and dashes'), findsOne);

    await enterFieldText(tester, label: 'Name', text: 'labs');
    await tapVisible(tester, find.text('Create workspace').last);
    await pumpFrames(tester);

    expect(dependencies.workspaceRepository.currentWorkspace().name, 'labs');
    expect(find.text('labs workspace'), findsOneWidget);
    expect(find.text('No projects yet'), findsOneWidget);
  });

  testWidgets(
    'test_projects_screen_property_workspace_link_only_when_narrow',
    (WidgetTester tester) async {
      final Random random = seededRandom(9002);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final double width = randomWidth(
          random,
          least: narrowestWidth,
          most: widestWidth,
        );
        final bool isNarrow = width < LayoutSize.mediumMinimumWidth;
        await pumpApp(
          tester,
          size: Size(width, desktopHeight),
          route: _projectsRoute,
          dependencies: buildGalleryDependencies(),
        );

        expect(
          find.text(_workspaceLinkText),
          isNarrow ? findsOne : findsNothing,
          reason: 'at $width',
        );
      }
    },
  );

  testWidgets('test_project_screens_fuzz_property_render_at_any_width', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9001);
    final List<AppRoute> routes = <AppRoute>[
      _projectsRoute,
      const WorkspaceSwitcherRoute(),
      const NewProjectRoute(),
      const ProjectRoute(GalleryProjectIds.acmeApp),
    ];

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = randomWidth(
        random,
        least: narrowestWidth,
        most: widestWidth,
      );
      final AppRoute route = pickOne(random, routes);
      await pumpApp(
        tester,
        size: Size(width, desktopHeight),
        route: route,
        dependencies: buildGalleryDependencies(),
      );

      expect(tester.takeException(), isNull, reason: '$route at $width');
    }
  });
}
