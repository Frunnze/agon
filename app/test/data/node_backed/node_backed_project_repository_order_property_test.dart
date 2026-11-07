import 'support/ordered_project_reply_race.dart';
import 'support/reply_race_properties.dart';

typedef _ProjectStep = ReplyRaceStep<OrderedProjectReplyRace>;

void main() {
  registerReplyRaceProperties(
    openRace: openOrderedProjectReplyRace,
    raceCase: const ReplyRaceCase<OrderedProjectReplyRace>(
      testedName: 'node_backed_project_repository_create_project',
      seed: 81701,
      localSteps: <_ProjectStep>[createOrderedRaceProject],
      elsewhereSteps: <_ProjectStep>[
        addOrderedProjectElsewhere,
        deleteOrderedProjectElsewhere,
      ],
    ),
  );
}
