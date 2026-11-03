import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/person_step.dart';
import 'package:agent_orchestration/data/repository/person_step_repository.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/rules/person_answers.dart';

const String _openStepKind = 'open person step';

final class FakePersonStepRepository extends ChangeNotifier
    implements PersonStepRepository {
  FakePersonStepRepository({required List<OpenPersonStep> openSteps})
    : _openSteps = List<OpenPersonStep>.unmodifiable(openSteps);

  List<OpenPersonStep> _openSteps;

  @override
  List<OpenPersonStep> listOpenPersonSteps() => _openSteps;

  @override
  Future<void> answerPersonStep({
    required RunId runId,
    required String stepName,
    required String answer,
  }) async {
    if (answer.trim().isEmpty) {
      throw ArgumentError.value(answer, 'answer', 'Write an answer first');
    }
    final OpenPersonStep openStep = findRecord(
      _openSteps,
      matches: (OpenPersonStep candidate) =>
          candidate.runId == runId && candidate.stepName == stepName,
      kind: _openStepKind,
      identifier: stepName,
    );
    final bool isUnmatched =
        openStep.choices.isNotEmpty &&
        matchChoice(answer, openStep.choices) == null;
    if (isUnmatched) {
      throw StateError(describeUnmatchedAnswer(openStep.choices));
    }

    _openSteps = removeRecord(
      _openSteps,
      matches: (OpenPersonStep candidate) => identical(candidate, openStep),
    );
    notifyListeners();
  }
}
