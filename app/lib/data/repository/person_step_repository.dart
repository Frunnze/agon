import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/person_step.dart';

abstract interface class PersonStepRepository implements Listenable {
  List<OpenPersonStep> listOpenPersonSteps();

  Future<void> answerPersonStep({
    required RunId runId,
    required String stepName,
    required String answer,
  });
}
