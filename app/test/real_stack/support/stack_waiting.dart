import 'package:flutter_test/flutter_test.dart';

const Duration _fakeTimeStep = Duration(milliseconds: 250);
const Duration _realTimeStep = Duration(milliseconds: 25);
const Duration _waitLimit = Duration(seconds: 90);
const Duration _transitionTime = Duration(milliseconds: 800);

typedef NodeCheck = Future<bool> Function();

Future<void> letRealWorkHappen(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(_realTimeStep));
  await tester.pump(_fakeTimeStep);
}

Future<void> waitUntilTrue(
  WidgetTester tester, {
  required String description,
  required bool Function() isReached,
}) async {
  final DateTime deadline = DateTime.now().add(_waitLimit);
  await tester.pump();
  while (!isReached()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure('Gave up waiting for $description');
    }
    await letRealWorkHappen(tester);
  }
}

Future<void> waitUntilShown(WidgetTester tester, Finder finder) {
  return waitUntilTrue(
    tester,
    description: 'the screen to show ${finder.describeMatch(Plurality.one)}',
    isReached: () => finder.evaluate().isNotEmpty,
  );
}

Future<void> waitUntilGone(WidgetTester tester, Finder finder) {
  return waitUntilTrue(
    tester,
    description: 'the screen to hide ${finder.describeMatch(Plurality.one)}',
    isReached: () => finder.evaluate().isEmpty,
  );
}

Future<Answer> askNode<Answer>(
  WidgetTester tester,
  Future<Answer> Function() question,
) async {
  final List<Answer> answers = <Answer>[];
  await tester.runAsync(() async {
    answers.add(await question());
  });
  if (answers.isEmpty) {
    throw TestFailure('The node did not answer the question');
  }
  return answers.single;
}

Future<void> waitUntilNodeAgrees(
  WidgetTester tester, {
  required String description,
  required NodeCheck check,
}) async {
  final DateTime deadline = DateTime.now().add(_waitLimit);
  while (!await askNode(tester, check)) {
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure('Gave up waiting for the node to show $description');
    }
    await letRealWorkHappen(tester);
  }
}

Future<Answer> waitUntilScreenShowsNodeAnswer<Answer>(
  WidgetTester tester, {
  required String description,
  required Future<Answer> Function() question,
  required bool Function(Answer answer) isShown,
}) async {
  final DateTime deadline = DateTime.now().add(_waitLimit);
  Answer answer = await askNode(tester, question);
  while (!isShown(answer)) {
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure('Gave up waiting for the screen to show $description');
    }
    await letRealWorkHappen(tester);
    answer = await askNode(tester, question);
  }
  return answer;
}

Future<void> tapAndWait(
  WidgetTester tester,
  Finder target, {
  required Finder expected,
}) async {
  await tapWhenShown(tester, target);
  await waitUntilShown(tester, expected);
}

Future<void> tapWhenShown(WidgetTester tester, Finder target) async {
  await waitUntilShown(tester, target);
  await tester.pump(_transitionTime);
  await tester.ensureVisible(target);
  await tester.pump(_transitionTime);
  await tester.tap(target);
  await tester.pump();
}
