import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'support/deletion_review_harness.dart';

double _randomWindowWidth(Random random) {
  return randomWidth(random, least: narrowestWidth, most: widestWidth);
}

String _randomRefusal(Random random) {
  return 'Refused ${randomText(random)}';
}

Future<void> _refuseAfterNoting(List<String> attempts, String refusal) {
  attempts.add(refusal);
  return Future<void>.error(StateError(refusal));
}

void main() {
  testWidgets('test_review_deletion_property_refused_delete_returns_to_the_'
      'page', (WidgetTester tester) async {
    final Random random = seededRandom(52801);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String refusal = _randomRefusal(random);
      final List<AppRoute> startingRoutes = randomRoutesUnderTheRecord(random);
      final DeletionReviewRig rig = DeletionReviewRig(
        startingRoutes: startingRoutes,
        prompt: randomDeletionPrompt(random),
        deleteRecord: () => Future<void>.error(StateError(refusal)),
      );
      await pumpDeletionReview(
        tester,
        rig: rig,
        width: _randomWindowWidth(random),
      );

      await confirmDeletion(tester, rig: rig);

      expect(tester.takeException(), isNull);
      expect(rig.navigation.routes, startingRoutes);
      expect(find.text(openDeletionLabel), findsOneWidget);
      expect(find.text(describeRefusalTitle(rig.prompt)), findsOneWidget);
      expect(find.text(refusal), findsOneWidget);
      await tapAppButton(tester, rig.prompt.keepLabel);
      expect(await rig.reviewOutcomes.single, isNull);
    }
  });

  testWidgets('test_review_deletion_property_refusal_offers_only_keeping', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(52802);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<String> attempts = <String>[];
      final String refusal = _randomRefusal(random);
      final List<AppRoute> startingRoutes = randomRoutesUnderTheRecord(random);
      final DeletionReviewRig rig = DeletionReviewRig(
        startingRoutes: startingRoutes,
        prompt: randomDeletionPrompt(random),
        deleteRecord: () => _refuseAfterNoting(attempts, refusal),
      );
      await pumpDeletionReview(
        tester,
        rig: rig,
        width: _randomWindowWidth(random),
      );
      await confirmDeletion(tester, rig: rig);

      expect(
        find.widgetWithText(AppButton, rig.prompt.deleteLabel),
        findsNothing,
      );
      await tapAppButton(tester, rig.prompt.keepLabel);

      expect(find.text(describeRefusalTitle(rig.prompt)), findsNothing);
      expect(find.text(openDeletionLabel), findsOneWidget);
      expect(rig.navigation.routes, startingRoutes);
      expect(attempts, <String>[refusal]);
    }
  });

  testWidgets('test_review_deletion_property_moved_on_person_stays_where_'
      'they_went', (WidgetTester tester) async {
    final Random random = seededRandom(52803);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Completer<void> answer = Completer<void>();
      final String refusal = _randomRefusal(random);
      final DeletionReviewRig rig = DeletionReviewRig(
        startingRoutes: randomRoutesUnderTheRecord(random),
        prompt: randomDeletionPrompt(random),
        deleteRecord: () => answer.future,
      );
      final SectionRoute elsewhere = SectionRoute(
        pickOne(random, AppSection.values),
      );
      await pumpDeletionReview(
        tester,
        rig: rig,
        width: _randomWindowWidth(random),
      );
      await confirmDeletion(tester, rig: rig);

      rig.navigation.openSection(elsewhere);
      answer.completeError(StateError(refusal));
      await pumpFrames(tester);

      expect(rig.navigation.routes, <AppRoute>[elsewhere]);
      expect(find.text(refusal), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tapAppButton(tester, rig.prompt.keepLabel);
    }
  });

  testWidgets('test_review_deletion_property_successful_delete_stays_off_'
      'the_page', (WidgetTester tester) async {
    final Random random = seededRandom(52804);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<int> deletions = <int>[];
      final DeletionReviewRig rig = DeletionReviewRig(
        startingRoutes: randomRoutesUnderTheRecord(random),
        prompt: randomDeletionPrompt(random),
        deleteRecord: () async => deletions.add(i),
      );
      await pumpDeletionReview(
        tester,
        rig: rig,
        width: _randomWindowWidth(random),
      );

      await confirmDeletion(tester, rig: rig);

      expect(rig.navigation.currentRoute, reviewListRoute);
      expect(find.text(listPageText), findsOneWidget);
      expect(find.text(describeRefusalTitle(rig.prompt)), findsNothing);
      expect(deletions, <int>[i]);
      expect(await rig.reviewOutcomes.single, isNull);
    }
  });

  testWidgets('test_review_deletion_property_deletes_once_the_page_is_gone', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(52805);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<bool> pageShownAtDeletion = <bool>[];
      late final DeletionReviewRig rig;
      rig = DeletionReviewRig(
        startingRoutes: randomRoutesUnderTheRecord(random),
        prompt: randomDeletionPrompt(random),
        deleteRecord: () async =>
            pageShownAtDeletion.add(rig.recordPageKey.currentContext != null),
      );
      await pumpDeletionReview(
        tester,
        rig: rig,
        width: _randomWindowWidth(random),
      );

      await confirmDeletion(tester, rig: rig);

      expect(pageShownAtDeletion, <bool>[false]);
    }
  });

  testWidgets('test_review_deletion_property_unexplained_problem_is_not_'
      'hidden', (WidgetTester tester) async {
    final Random random = seededRandom(52806);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DeletionReviewRig rig = DeletionReviewRig(
        startingRoutes: randomRoutesUnderTheRecord(random),
        prompt: randomDeletionPrompt(random),
        deleteRecord: () => Future<void>.error(RangeError(randomText(random))),
      );
      await pumpDeletionReview(
        tester,
        rig: rig,
        width: _randomWindowWidth(random),
      );

      await confirmDeletion(tester, rig: rig);

      expect(await rig.reviewOutcomes.single, isA<RangeError>());
      expect(find.text(describeRefusalTitle(rig.prompt)), findsNothing);
    }
  });

  testWidgets('test_review_deletion_property_keep_never_deletes', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(52807);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<int> deletions = <int>[];
      final List<AppRoute> startingRoutes = randomRoutesUnderTheRecord(random);
      final DeletionReviewRig rig = DeletionReviewRig(
        startingRoutes: startingRoutes,
        prompt: randomDeletionPrompt(random),
        deleteRecord: () async => deletions.add(i),
      );
      await pumpDeletionReview(
        tester,
        rig: rig,
        width: _randomWindowWidth(random),
      );

      await tapAppButton(tester, openDeletionLabel);
      await tapAppButton(tester, rig.prompt.keepLabel);

      expect(deletions, isEmpty);
      expect(rig.navigation.routes, startingRoutes);
      expect(await rig.reviewOutcomes.single, isNull);
    }
  });
}
