import 'dart:math';

import '../../support/random_inputs.dart';
import 'node_json_primitives.dart';
import 'node_wire_names.dart';

Map<String, Object?> randomEarlierRoundJson(Random random) {
  return <String, Object?>{
    'status': pickOne(random, nodeStepStatuses),
    'started_at': randomOptional(random, randomMomentText),
    'finished_at': randomOptional(random, randomMomentText),
    'result': randomOptional(random, randomText),
    'outcome': randomOptional(random, randomText),
  };
}

Map<String, Object?> randomLoopRoundsJson(Random random) {
  return <String, Object?>{
    'from': randomText(random),
    'to': randomText(random),
    'rounds': randomCount(random),
  };
}

Map<String, Object?> randomRunNoteJson(Random random) {
  return <String, Object?>{
    'at': randomMomentText(random),
    'text': randomText(random),
  };
}

Map<String, Object?> randomOpenPersonStepJson(Random random) {
  return <String, Object?>{
    'run_id': randomUuidText(random),
    'task_id': randomUuidText(random),
    'workspace_id': randomUuidText(random),
    'step_name': randomText(random),
    'question': randomText(random),
    'choices': randomTexts(random),
    'asked_at': randomOptional(random, randomMomentText),
  };
}
