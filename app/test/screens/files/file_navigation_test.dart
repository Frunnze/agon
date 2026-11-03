import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_files.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/data/repository/file_repository.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../bridge/support/random_typed_values.dart';
import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import 'file_screen_steps.dart';

final class _CountingFileRepository implements FileRepository {
  _CountingFileRepository(this._inner);

  final FileRepository _inner;
  final List<DeviceId?> askedPreferences = <DeviceId?>[];

  @override
  Future<RepositoryFileSource> openRepository({
    required ProjectId projectId,
    required String repositoryAddress,
    required DeviceId? preferredRunnerId,
  }) {
    askedPreferences.add(preferredRunnerId);
    return _inner.openRepository(
      projectId: projectId,
      repositoryAddress: repositoryAddress,
      preferredRunnerId: preferredRunnerId,
    );
  }

  @override
  Future<List<RepositoryEntry>> listFolder({
    required RepositoryBranchLocation location,
    required String folder,
  }) {
    return _inner.listFolder(location: location, folder: folder);
  }

  @override
  Future<RepositoryFile> readFile({
    required RepositoryBranchLocation location,
    required String path,
  }) {
    return _inner.readFile(location: location, path: path);
  }
}

final class _RefusingFileRepository implements FileRepository {
  const _RefusingFileRepository();

  @override
  Future<RepositoryFileSource> openRepository({
    required ProjectId projectId,
    required String repositoryAddress,
    required DeviceId? preferredRunnerId,
  }) async {
    throw StateError('the runner refused to show the files');
  }

  @override
  Future<List<RepositoryEntry>> listFolder({
    required RepositoryBranchLocation location,
    required String folder,
  }) async {
    throw StateError('unused');
  }

  @override
  Future<RepositoryFile> readFile({
    required RepositoryBranchLocation location,
    required String path,
  }) async {
    throw StateError('unused');
  }
}

AppDependencies _withFiles(FileRepository fileRepository) {
  return replaceRepositories(
    buildGalleryDependencies(),
    fileRepository: fileRepository,
  );
}

void main() {
  testWidgets('browse files opens the first repository', (
    WidgetTester tester,
  ) async {
    final AppNavigation navigation = await pumpApp(
      tester,
      size: desktopSize,
      route: const ProjectRoute(GalleryProjectIds.acmeApp),
      dependencies: buildGalleryDependencies(),
    );

    await tester.tap(find.text('Browse files'));
    await pumpFrames(tester);

    expect(navigation.currentRoute, appFilesRoute);
    expect(find.text('From office-server · encrypted'), findsOneWidget);
  });

  testWidgets('folders collapse again when tapped twice', (
    WidgetTester tester,
  ) async {
    await openFiles(tester, size: phoneSize, route: appFilesRoute);

    await tapTreeRow(tester, 'src');
    expect(find.text('App.tsx'), findsOneWidget);
    await tapTreeRow(tester, 'src');
    expect(find.text('App.tsx'), findsNothing);
  });

  testWidgets('picking a branch or repository changes the files route', (
    WidgetTester tester,
  ) async {
    final AppNavigation navigation = await openFiles(
      tester,
      size: desktopSize,
      route: appFilesRoute,
    );

    await choosePickerOption(tester, label: 'Branch', option: 'release');
    expect(
      navigation.currentRoute,
      const ProjectFilesRoute(
        projectId: GalleryProjectIds.acmeApp,
        repositoryAddress: galleryAppRepositoryAddress,
        branch: 'release',
        preferredRunnerId: GalleryDeviceIds.officeServer,
      ),
    );
    await choosePickerOption(tester, label: 'Repository', option: 'acme/api');
    expect(navigation.currentRoute, apiFilesRoute);
    expect(navigation.routes.length, 1);
  });

  testWidgets(
    'test_project_files_screen_property_asks_for_the_preferred_runner',
    (WidgetTester tester) async {
      final Random random = seededRandom(9711);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final DeviceId? preferred = random.nextBool()
            ? randomDeviceId(random)
            : null;
        final _CountingFileRepository counting = _CountingFileRepository(
          buildGalleryDependencies().fileRepository,
        );

        await openFiles(
          tester,
          size: phoneSize,
          route: ProjectFilesRoute(
            projectId: GalleryProjectIds.acmeApp,
            repositoryAddress: galleryAppRepositoryAddress,
            preferredRunnerId: preferred,
          ),
          dependencies: _withFiles(counting),
        );

        expect(counting.askedPreferences, <DeviceId?>[preferred]);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  testWidgets('a branch picked on a file page keeps its runner', (
    WidgetTester tester,
  ) async {
    final AppNavigation navigation = await openFiles(
      tester,
      size: desktopSize,
      route: appFilesRoute,
    );
    await openTreePath(tester, <String>['src', 'auth', 'login.ts']);

    await choosePickerOption(tester, label: 'Branch', option: 'release');

    expect(
      navigation.currentRoute,
      const ProjectFilesRoute(
        projectId: GalleryProjectIds.acmeApp,
        repositoryAddress: galleryAppRepositoryAddress,
        branch: 'release',
        preferredRunnerId: GalleryDeviceIds.officeServer,
      ),
    );
  });

  testWidgets('the breadcrumb returns to the files page', (
    WidgetTester tester,
  ) async {
    final AppNavigation navigation = await openFiles(
      tester,
      size: phoneSize,
      route: appFilesRoute,
    );
    await openTreePath(tester, <String>['src', 'auth', 'login.ts']);
    expect(navigation.currentRoute, isA<RepositoryFileRoute>());

    await tester.tap(find.text('auth'));
    await pumpFrames(tester);

    expect(navigation.currentRoute, appFilesRoute);
    expect(navigation.routes.length, 1);
  });

  testWidgets('a file picked in the side tree replaces the file page', (
    WidgetTester tester,
  ) async {
    final AppNavigation navigation = await openFiles(
      tester,
      size: desktopSize,
      route: appFilesRoute,
    );
    await tapTreeRow(tester, 'package.json');
    await tapTreeRow(tester, 'tsconfig.json');

    expect(navigation.routes.length, 2);
    expect(
      (navigation.currentRoute as RepositoryFileRoute).path,
      'tsconfig.json',
    );
  });

  testWidgets('copy path puts the file path on the clipboard', (
    WidgetTester tester,
  ) async {
    final List<Object?> copied = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map<Object?, Object?>)['text']);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await openFiles(tester, size: phoneSize, route: appFilesRoute);
    await openTreePath(tester, <String>['src', 'auth', 'redirect.ts']);

    await tester.tap(find.text('Copy path'));
    await pumpFrames(tester);

    expect(copied, <Object?>['src/auth/redirect.ts']);
  });

  testWidgets('try again opens the repository again', (
    WidgetTester tester,
  ) async {
    final _CountingFileRepository counting = _CountingFileRepository(
      buildGalleryDependencies().fileRepository,
    );
    await openFiles(
      tester,
      size: phoneSize,
      route: apiFilesRoute,
      dependencies: _withFiles(counting),
    );

    await tester.tap(find.text('Try again'));
    await pumpFrames(tester);

    expect(counting.askedPreferences.length, 2);
    expect(find.text('No runner with acme/api is online'), findsOneWidget);
  });

  testWidgets('see runners opens the runners settings', (
    WidgetTester tester,
  ) async {
    final AppNavigation navigation = await openFiles(
      tester,
      size: desktopSize,
      route: apiFilesRoute,
    );

    await tester.tap(find.text('See runners'));
    await pumpFrames(tester);

    expect(navigation.currentRoute, const RunnersSettingsRoute());
  });

  testWidgets('a refused opening shows the problem', (
    WidgetTester tester,
  ) async {
    await openFiles(
      tester,
      size: phoneSize,
      route: appFilesRoute,
      dependencies: _withFiles(const _RefusingFileRepository()),
    );

    expect(find.text('the runner refused to show the files'), findsOneWidget);
    expect(find.text('Files'), findsOneWidget);
  });
}
