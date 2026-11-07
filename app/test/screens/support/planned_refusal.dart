import 'dart:math';

import 'package:agent_orchestration/data/repository/app_server_refusal.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_app_server_refusals.dart';
import '../../support/random_inputs.dart';

const String _recordKind = 'record';

typedef ProceedWithAction<Result> = Future<Result> Function();

typedef ExplainedRefusal = ({Object problem, String explanation});

final class PlannedRefusal {
  Object? problem;
  int attempts = 0;

  Future<Result> refuseOr<Result>(ProceedWithAction<Result> proceed) {
    attempts += 1;
    final Object? plannedProblem = problem;
    if (plannedProblem == null) {
      return proceed();
    }
    return Future<Result>.error(plannedProblem);
  }
}

ExplainedRefusal randomExplainedRefusal(Random random) {
  final String reason = randomRefusalReason(random);
  final RandomRefusal serverRefusal = randomRefusalWithReason(random, reason);
  final List<ExplainedRefusal> refusals = <ExplainedRefusal>[
    (problem: StateError(reason), explanation: reason),
    (problem: ArgumentError(reason), explanation: reason),
    (
      problem: AppServerRefusal(status: serverRefusal.status, reason: reason),
      explanation: reason,
    ),
    (
      problem: RecordNotFound(kind: _recordKind, identifier: reason),
      explanation: 'No $_recordKind with id $reason',
    ),
  ];
  return pickOne(random, refusals);
}

FormatException randomUnexplainedProblem(Random random) {
  return FormatException(randomRefusalReason(random));
}
