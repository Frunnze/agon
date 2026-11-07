import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/screens/shared/deletion_prompts.dart';
import 'package:agent_orchestration/screens/shared/deletion_review.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../../support/app_harness.dart';
import '../../../support/form_finders.dart';
import '../../../support/random_inputs.dart';
import '../../../support/widget_harness.dart';

const String openDeletionLabel = 'Open the deletion';
const String listPageText = 'The list page';
const SectionRoute reviewListRoute = SectionRoute(AppSection.projects);
const ProjectRoute reviewedRecordRoute = ProjectRoute(
  ProjectId('project-under-review'),
);
const int _largestStackDepthBelow = 3;

DeletionPrompt randomDeletionPrompt(Random random) {
  return DeletionPrompt(
    title: 'Title ${randomText(random)}',
    explanation: 'Explanation ${randomText(random)}',
    keepLabel: 'Keep ${randomWordPhrase(random)}',
    deleteLabel: 'Remove ${randomWordPhrase(random)}',
  );
}

List<AppRoute> randomRoutesUnderTheRecord(Random random) {
  final List<AppRoute> routes = <AppRoute>[
    SectionRoute(pickOne(random, AppSection.values)),
  ];
  final int extraDepth = random.nextInt(_largestStackDepthBelow);
  for (int i = 0; i < extraDepth; i += 1) {
    routes.add(EditTaskRoute(TaskId('task-${random.nextInt(9)}')));
  }
  if (random.nextBool()) {
    routes.add(reviewListRoute);
  }
  return <AppRoute>[...routes, reviewedRecordRoute];
}

Future<Object?> catchReviewProblem(Future<void> review) async {
  try {
    await review;
  } on Object catch (problem) {
    return problem;
  }
  return null;
}

final class DeletionReviewRig {
  DeletionReviewRig({
    required List<AppRoute> startingRoutes,
    required this.prompt,
    required this.deleteRecord,
  }) : navigation = AppNavigation(initialRoute: startingRoutes.first) {
    navigation.restoreRoutes(startingRoutes);
  }

  final AppNavigation navigation;
  final DeletionPrompt prompt;
  final RecordDeletion deleteRecord;
  final GlobalKey recordPageKey = GlobalKey();
  final List<Future<Object?>> reviewOutcomes = <Future<Object?>>[];

  void startReview(BuildContext pageContext) {
    final Future<void> review = reviewDeletion(
      context: pageContext,
      prompt: prompt,
      navigation: navigation,
      leavePage: () => navigation.returnTo(reviewListRoute),
      deleteRecord: deleteRecord,
    );
    reviewOutcomes.add(catchReviewProblem(review));
  }
}

class DeletionReviewHarness extends StatelessWidget {
  const DeletionReviewHarness({required this.rig, super.key});

  final DeletionReviewRig rig;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: rig.navigation, builder: _buildRoute);
  }

  Widget _buildRoute(BuildContext context, Widget? _) {
    if (rig.navigation.currentRoute != reviewedRecordRoute) {
      return const Text(listPageText);
    }
    return _RecordPage(key: rig.recordPageKey, rig: rig);
  }
}

class _RecordPage extends StatelessWidget {
  const _RecordPage({required this.rig, super.key});

  final DeletionReviewRig rig;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppButton.secondary(
        label: openDeletionLabel,
        onPressed: () => rig.startReview(context),
      ),
    );
  }
}

Future<void> pumpDeletionReview(
  WidgetTester tester, {
  required DeletionReviewRig rig,
  required double width,
}) async {
  useViewSize(tester, Size(width, desktopHeight));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    wrapInApp(
      DeletionReviewHarness(rig: rig),
      platform: platformMeantByWidth(width),
    ),
  );
  await tester.pump();
}

Future<void> tapAppButton(WidgetTester tester, String label) async {
  await tapVisible(tester, find.widgetWithText(AppButton, label).last);
  await pumpFrames(tester);
}

Future<void> confirmDeletion(
  WidgetTester tester, {
  required DeletionReviewRig rig,
}) async {
  await tapAppButton(tester, openDeletionLabel);
  await tapAppButton(tester, rig.prompt.deleteLabel);
}

String describeRefusalTitle(DeletionPrompt prompt) {
  return '${prompt.deleteLabel} did not work';
}
