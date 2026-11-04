import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_runs.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/rules/kept_branches.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/kept_branch_text.dart';
import 'package:agent_orchestration/screens/files/project_files_screen.dart';
import 'package:agent_orchestration/screens/shared/status_labels.dart';
import 'package:agent_orchestration/screens/task_run/not_pushed_banner.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/status_label.dart';

import '../support/app_harness.dart';
import '../support/random_inputs.dart';
import '../support/widget_harness.dart';

const String _bannerTitle = 'The work stayed on its branch and was not pushed';
const String _browseLabel = 'Browse the branch in acme/app';
const String _bannerBody =
    'The push to acme/app was denied, so its commits stay on '
    '$galleryKeptBranch on office-server.';
const List<String> _repositories = <String>[
  'github.com/acme/app',
  'github.com/acme/api',
  'gitlab.com/tools/ranker',
];
const List<DeviceId> _runners = <DeviceId>[
  GalleryDeviceIds.officeServer,
  GalleryDeviceIds.macStudio,
  GalleryDeviceIds.gpuBox,
];

KeptBranch _randomKeptBranch(Random random, String repository) {
  return KeptBranch(
    repositoryAddress: repository,
    branch: 'task/${randomWordPhrase(random).replaceAll(' ', '-')}',
    runner: pickOne(random, _runners),
  );
}

List<KeptBranch> _randomKeptBranches(Random random, int count) {
  final List<String> repositories = <String>[..._repositories]
    ..shuffle(random);
  return <KeptBranch>[
    for (final String repository in repositories.take(count))
      _randomKeptBranch(random, repository),
  ];
}

String _joinSegments(List<TextSegment> segments) {
  return <String>[for (final TextSegment segment in segments) segment.text]
      .join();
}

void main() {
  final DeviceNames deviceNames = DeviceNames(galleryDevices);

  test(
    'test_build_task_outcome_label_property_kept_work_reads_not_pushed',
    () {
      final Random random = seededRandom(95);

      for (int i = 0; i < propertyIterations; i += 1) {
        final TaskStatus status = pickOne(random, TaskStatus.values);
        final List<KeptBranch> keptBranches = _randomKeptBranches(
          random,
          random.nextInt(_repositories.length + 1),
        );

        final StatusLabel label = buildTaskOutcomeLabel(
          status: status,
          keptBranches: keptBranches,
        );

        final StatusLabel plain = buildTaskStatusLabel(status);
        expect(label.text == 'Not pushed', keptBranches.isNotEmpty);
        if (keptBranches.isEmpty) {
          expect(label.text, plain.text);
          expect(label.tone, plain.tone);
        }
      }
    },
  );

  test('test_describe_kept_branch_property_names_branch_runner_and_repo', () {
    final Random random = seededRandom(96);

    for (int i = 0; i < propertyIterations; i += 1) {
      final KeptBranch kept = _randomKeptBranch(
        random,
        pickOne(random, _repositories),
      );

      final List<TextSegment> segments = describeKeptBranch(
        kept: kept,
        deviceNames: deviceNames,
      );

      final String sentence = _joinSegments(segments);
      final String path = kept.repositoryAddress.split('/').skip(1).join('/');
      expect(sentence, contains('The push to $path was denied'));
      expect(sentence, contains(deviceNames.nameOf(kept.runner)));
      final TextSegment branch = segments.firstWhere(
        (TextSegment segment) => segment.face == TextFace.monospace,
      );
      expect(branch.text, kept.branch);
      expect(describeKeptBranchLink(kept), 'Browse the branch in $path');
    }
  });

  testWidgets('test_not_pushed_banner_property_offers_every_kept_branch', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(97);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<KeptBranch> keptBranches = _randomKeptBranches(
        random,
        1 + random.nextInt(_repositories.length),
      );
      final List<KeptBranch> browsed = <KeptBranch>[];
      useViewSize(tester, desktopSize);
      await tester.pumpWidget(
        wrapInApp(
          NotPushedBanner(
            keptBranches: keptBranches,
            deviceNames: deviceNames,
            onBrowse: browsed.add,
          ),
          platform: desktopPlatform,
        ),
      );

      expect(find.text(_bannerTitle), findsOneWidget);
      for (final KeptBranch kept in keptBranches) {
        final String sentence = _joinSegments(
          describeKeptBranch(kept: kept, deviceNames: deviceNames),
        );
        expect(find.text(sentence, findRichText: true), findsOneWidget);
        await tester.tap(find.text(describeKeptBranchLink(kept)));
      }
      expect(browsed, keptBranches);
    }
  });

  for (final Size size in <Size>[phoneSize, desktopSize]) {
    testWidgets('a denied push reads Not pushed on the tasks page at '
        '${size.width}', (WidgetTester tester) async {
      await pumpApp(
        tester,
        size: size,
        route: const SectionRoute(AppSection.tasks),
        dependencies: buildGalleryDependencies(),
      );

      expect(find.text('Rename the billing module'), findsOneWidget);
      expect(find.text('2 days ago'), findsOneWidget);
      expect(find.text('Not pushed'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('the run page says the work stayed on its branch at '
        '${size.width}', (WidgetTester tester) async {
      await pumpApp(
        tester,
        size: size,
        route: const TaskRunRoute(GalleryRunIds.renameBillingModule1),
        dependencies: buildGalleryDependencies(),
      );

      expect(find.text('Rename the billing module #1'), findsOneWidget);
      expect(
        find.text(
          'Rename the billing module · acme-app · finished 2 days ago',
        ),
        findsOneWidget,
      );
      expect(find.text(_bannerTitle), findsOneWidget);
      expect(find.text(_bannerBody, findRichText: true), findsOneWidget);
      expect(find.text(_browseLabel), findsOneWidget);
      expect(find.text('office-server · 15 min 30 s'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Ask the agent'), findsOneWidget);
      expect(find.textContaining('Retry'), findsNothing);
    });
  }

  testWidgets('runs without a denied push show no kept branch', (
    WidgetTester tester,
  ) async {
    for (final RunId runId in <RunId>[
      GalleryRunIds.release41,
      GalleryRunIds.release42,
      GalleryRunIds.writeApiDocs1,
    ]) {
      await pumpApp(
        tester,
        size: desktopSize,
        route: TaskRunRoute(runId),
        dependencies: buildGalleryDependencies(),
      );

      expect(find.text(_bannerTitle), findsNothing);
    }
  });

  testWidgets('browsing the kept branch opens its files', (
    WidgetTester tester,
  ) async {
    final AppNavigation navigation = await pumpApp(
      tester,
      size: desktopSize,
      route: const TaskRunRoute(GalleryRunIds.renameBillingModule1),
      dependencies: buildGalleryDependencies(),
    );

    await tester.tap(find.text(_browseLabel));
    await pumpFrames(tester);

    final AppRoute route = navigation.currentRoute;
    expect(find.byType(ProjectFilesScreen), findsOneWidget);
    expect(route, isA<ProjectFilesRoute>());
    final ProjectFilesRoute filesRoute = route as ProjectFilesRoute;
    expect(filesRoute.projectId, GalleryProjectIds.acmeApp);
    expect(filesRoute.repositoryAddress, 'github.com/acme/app');
    expect(filesRoute.branch, galleryKeptBranch);
    expect(filesRoute.preferredRunnerId, GalleryDeviceIds.officeServer);
    expect(find.text(galleryKeptBranch), findsWidgets);
  });
}
