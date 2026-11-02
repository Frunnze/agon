import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_files.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../support/app_harness.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';

const String _removeLabel = 'Remove';
const String _confirmRemovalLabel = 'Remove repo';
const String _closeLabel = 'Close';
const ProjectRoute _acmeAppRoute = ProjectRoute(GalleryProjectIds.acmeApp);
const List<Size> _layoutSizes = <Size>[phoneSize, desktopSize];
const List<String> _galleryAddresses = <String>[
  galleryAppRepositoryAddress,
  galleryApiRepositoryAddress,
];

Finder _findRemoveButtons() {
  return find.widgetWithText(AppButton, _removeLabel);
}

List<String> _readAcmeAppAddresses(AppDependencies dependencies) {
  final Project project = dependencies.projectRepository.findProject(
    GalleryProjectIds.acmeApp,
  );
  final List<String> addresses = <String>[];
  for (final Repository repository in project.repositories) {
    addresses.add(repository.address);
  }
  return addresses;
}

Future<AppNavigation> _openAcmeApp(
  WidgetTester tester, {
  required Size size,
  required AppDependencies dependencies,
}) {
  return pumpApp(
    tester,
    size: size,
    route: _acmeAppRoute,
    dependencies: dependencies,
  );
}

Future<void> _tapRemoveOnRow(WidgetTester tester, int rowIndex) async {
  await tapVisible(tester, _findRemoveButtons().at(rowIndex));
  await pumpFrames(tester);
}

Future<void> _confirmRemoval(WidgetTester tester) async {
  await tapVisible(tester, find.text(_confirmRemovalLabel));
  await pumpFrames(tester);
}

void main() {
  for (final Size size in _layoutSizes) {
    testWidgets('every repository row shows Remove at ${size.width}', (
      WidgetTester tester,
    ) async {
      await _openAcmeApp(
        tester,
        size: size,
        dependencies: buildGalleryDependencies(),
      );

      expect(_findRemoveButtons(), findsNWidgets(_galleryAddresses.length));
    });

    testWidgets('Remove asks before removing at ${size.width}', (
      WidgetTester tester,
    ) async {
      final AppDependencies dependencies = buildGalleryDependencies();
      final AppNavigation navigation = await _openAcmeApp(
        tester,
        size: size,
        dependencies: dependencies,
      );

      await _tapRemoveOnRow(tester, 1);

      expect(find.text(_confirmRemovalLabel), findsOneWidget);
      expect(find.text(galleryApiRepositoryAddress), findsOneWidget);
      expect(navigation.currentRoute, _acmeAppRoute);
      expect(_readAcmeAppAddresses(dependencies), _galleryAddresses);
    });

    testWidgets('confirming removes only that repo at ${size.width}', (
      WidgetTester tester,
    ) async {
      final AppDependencies dependencies = buildGalleryDependencies();
      await _openAcmeApp(tester, size: size, dependencies: dependencies);

      await _tapRemoveOnRow(tester, 1);
      await _confirmRemoval(tester);

      expect(find.text(_confirmRemovalLabel), findsNothing);
      expect(find.text('acme/api'), findsNothing);
      expect(find.text('acme/app'), findsOneWidget);
      expect(_findRemoveButtons(), findsOneWidget);
      expect(_readAcmeAppAddresses(dependencies), <String>[
        galleryAppRepositoryAddress,
      ]);
    });

    testWidgets('closing the confirmation keeps the repo at ${size.width}', (
      WidgetTester tester,
    ) async {
      final AppDependencies dependencies = buildGalleryDependencies();
      await _openAcmeApp(tester, size: size, dependencies: dependencies);

      await _tapRemoveOnRow(tester, 0);
      await tapVisible(tester, find.text(_closeLabel));
      await pumpFrames(tester);

      expect(find.text(_confirmRemovalLabel), findsNothing);
      expect(_findRemoveButtons(), findsNWidgets(_galleryAddresses.length));
      expect(_readAcmeAppAddresses(dependencies), _galleryAddresses);
    });

    testWidgets('a repository row still opens its files at ${size.width}', (
      WidgetTester tester,
    ) async {
      final AppNavigation navigation = await _openAcmeApp(
        tester,
        size: size,
        dependencies: buildGalleryDependencies(),
      );

      await tester.tap(find.text('acme/api'));
      await pumpFrames(tester);

      expect(
        navigation.currentRoute,
        const ProjectFilesRoute(
          projectId: GalleryProjectIds.acmeApp,
          repositoryAddress: galleryApiRepositoryAddress,
        ),
      );
    });
  }

  testWidgets(
    'test_remove_repository_button_property_removes_only_its_own_row',
    (WidgetTester tester) async {
      final Random random = seededRandom(7311);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final double width = randomWidth(
          random,
          least: narrowestWidth,
          most: widestWidth,
        );
        final int rowIndex = random.nextInt(_galleryAddresses.length);
        final AppDependencies dependencies = buildGalleryDependencies();
        final AppNavigation navigation = await _openAcmeApp(
          tester,
          size: Size(width, desktopHeight),
          dependencies: dependencies,
        );

        await _tapRemoveOnRow(tester, rowIndex);
        await _confirmRemoval(tester);

        final List<String> expectedAddresses = List<String>.of(
          _galleryAddresses,
        )..removeAt(rowIndex);
        final String reason = 'row $rowIndex at $width';
        expect(
          _readAcmeAppAddresses(dependencies),
          expectedAddresses,
          reason: reason,
        );
        expect(navigation.currentRoute, _acmeAppRoute, reason: reason);
      }
    },
  );
}
