import 'package:agent_orchestration/bridge/codecs/person_step_values.dart';
import 'package:agent_orchestration/bridge/codecs/run_round_values.dart';

import 'node_shapes.dart';
import 'random_branching_json.dart';

const List<NodeShape> branchingNodeShapes = <NodeShape>[
  NodeShape(
    'earlier_round_from_json',
    randomEarlierRoundJson,
    EarlierRound.fromJson,
  ),
  NodeShape(
    'loop_rounds_from_json',
    randomLoopRoundsJson,
    LoopRounds.fromJson,
  ),
  NodeShape('run_note_from_json', randomRunNoteJson, RunNote.fromJson),
  NodeShape(
    'open_person_step_from_json',
    randomOpenPersonStepJson,
    OpenPersonStep.fromJson,
  ),
];
