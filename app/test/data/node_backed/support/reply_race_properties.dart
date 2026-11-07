import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import '../../../support/random_inputs.dart';
import 'identifier_ordered_records.dart';
import 'out_of_order_replies.dart';

const int _raceIterations = 25;
const int _longestRace = 12;
const int _longestInOrderRun = 6;

abstract interface class ReplyRace {
  OutOfOrderReplyTransport get transport;

  PendingRaceWork get pendingWork;

  void deliverWaitingAnnouncement();

  Future<void> settle();

  List<String> describeShown();

  List<String> listShownIdentifiers();

  Future<List<String>> describeReload();

  void close();
}

typedef ReplyRaceStep<Race extends ReplyRace> = void Function(
  Random random,
  Race race,
);

typedef ReplyRaceOpening<Race extends ReplyRace> = Future<Race> Function(
  Random random,
);

final class ReplyRaceCase<Race extends ReplyRace> {
  const ReplyRaceCase({
    required this.testedName,
    required this.seed,
    required this.localSteps,
    required this.elsewhereSteps,
  });

  final String testedName;
  final int seed;
  final List<ReplyRaceStep<Race>> localSteps;
  final List<ReplyRaceStep<Race>> elsewhereSteps;
}

void releaseOneHeldReply(Random random, ReplyRace race) {
  race.transport.releaseRandomReply();
}

void deliverOneAnnouncement(Random random, ReplyRace race) {
  race.deliverWaitingAnnouncement();
}

List<ReplyRaceStep<Race>> _listRaceSteps<Race extends ReplyRace>(
  ReplyRaceCase<Race> raceCase,
) {
  return <ReplyRaceStep<Race>>[
    ...raceCase.localSteps,
    ...raceCase.elsewhereSteps,
    releaseOneHeldReply,
    deliverOneAnnouncement,
  ];
}

Future<void> _expectRaceEndsLikeAReload<Race extends ReplyRace>(
  ReplyRaceOpening<Race> openRace,
  ReplyRaceCase<Race> raceCase,
) async {
  final Random random = seededRandom(raceCase.seed);
  final List<ReplyRaceStep<Race>> steps = _listRaceSteps(raceCase);
  for (int i = 0; i < _raceIterations; i += 1) {
    final Race race = await openRace(random);
    final int stepCount = 1 + random.nextInt(_longestRace);

    for (int step = 0; step < stepCount; step += 1) {
      pickOne(random, steps)(random, race);
      await pumpEventQueue();
    }
    await race.settle();

    expect(race.describeShown(), await race.describeReload());
    race.close();
  }
}

Future<void> _expectInOrderRepliesMatchAReload<Race extends ReplyRace>(
  ReplyRaceOpening<Race> openRace,
  ReplyRaceCase<Race> raceCase,
) async {
  final Random random = seededRandom(raceCase.seed + 1);
  for (int i = 0; i < _raceIterations; i += 1) {
    final Race race = await openRace(random);
    race.transport.isHoldingReplies = false;
    final int stepCount = 1 + random.nextInt(_longestInOrderRun);

    for (int step = 0; step < stepCount; step += 1) {
      pickOne(random, raceCase.localSteps)(random, race);
      await race.pendingWork.finish();

      expect(race.describeShown(), await race.describeReload());
    }
    race.close();
  }
}

Future<void> _expectListingStaysInIdentifierOrder<Race extends ReplyRace>(
  ReplyRaceOpening<Race> openRace,
  ReplyRaceCase<Race> raceCase,
) async {
  final Random random = seededRandom(raceCase.seed + 2);
  final List<ReplyRaceStep<Race>> steps = _listRaceSteps(raceCase);
  for (int i = 0; i < _raceIterations; i += 1) {
    final Race race = await openRace(random);
    final int stepCount = 1 + random.nextInt(_longestRace);

    for (int step = 0; step < stepCount; step += 1) {
      pickOne(random, steps)(random, race);
      await pumpEventQueue();

      expect(isInIdentifierOrder(race.listShownIdentifiers()), isTrue);
    }
    await race.settle();

    expect(isInIdentifierOrder(race.listShownIdentifiers()), isTrue);
    race.close();
  }
}

void registerReplyRaceProperties<Race extends ReplyRace>({
  required ReplyRaceOpening<Race> openRace,
  required ReplyRaceCase<Race> raceCase,
}) {
  final String testedName = raceCase.testedName;
  test('test_${testedName}_property_late_replies_end_like_a_reload', () {
    return _expectRaceEndsLikeAReload(openRace, raceCase);
  });
  test('test_${testedName}_property_in_order_replies_match_a_reload', () {
    return _expectInOrderRepliesMatchAReload(openRace, raceCase);
  });
  test('test_${testedName}_property_listing_stays_in_identifier_order', () {
    return _expectListingStaysInIdentifierOrder(openRace, raceCase);
  });
}
