import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/person_step.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/repository/person_step_repository.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';
import 'package:agent_orchestration/data/rules/person_answers.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';
import 'package:agent_orchestration/data/rules/unicode_white_space.dart';

const String _openStepKind = 'open person step';

final class FakePersonStepRepository extends ChangeNotifier
    implements PersonStepRepository {
  FakePersonStepRepository({
    required List<OpenPersonStep> openSteps,
    required TaskRepository taskRepository,
  }) : _openSteps = List<OpenPersonStep>.unmodifiable(openSteps),
       _taskRepository = taskRepository {
    _taskRepository.addListener(notifyListeners);
  }

  final TaskRepository _taskRepository;
  List<OpenPersonStep> _openSteps;

  @override
  List<OpenPersonStep> listOpenPersonSteps() {
    final List<OpenPersonStep> askedSteps = <OpenPersonStep>[];
    for (final OpenPersonStep openStep in _openSteps) {
      if (_isRunStillActive(openStep)) {
        askedSteps.add(openStep);
      }
    }
    return List<OpenPersonStep>.unmodifiable(askedSteps);
  }

  @override
  Future<void> answerPersonStep({
    required RunId runId,
    required String stepName,
    required String answer,
  }) async {
    if (trimUnicodeWhiteSpace(answer).isEmpty) {
      throw ArgumentError.value(answer, 'answer', 'Write an answer first');
    }
    final OpenPersonStep openStep = findRecord(
      listOpenPersonSteps(),
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

  @override
  void dispose() {
    _taskRepository.removeListener(notifyListeners);
    super.dispose();
  }

  bool _isRunStillActive(OpenPersonStep openStep) {
    final List<Run> taskRuns = _taskRepository.listRuns(openStep.taskId);
    for (final Run run in taskRuns) {
      if (run.id == openStep.runId) {
        return isRunActive(run);
      }
    }
    return false;
  }
}
