import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/run_values.dart' as node;
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../bridge/support/list_copy_properties.dart';
import '../../bridge/support/random_moments.dart';
import '../../bridge/support/random_typed_values.dart';
import '../../support/random_inputs.dart';
import 'support/domain_model_properties.dart';
import 'support/random_run_records.dart';

const int _largestRunNumber = 1 << 20;
const int _statusFieldIndex = 3;
const int _stepsFieldIndex = 4;
const int _logFieldIndex = 5;
const int _chatFieldIndex = 6;
const int _failureFieldIndex = 7;
const int _finishedAtFieldIndex = 14;
const int _loopRoundsFieldIndex = 15;
const int _notesFieldIndex = 16;
const Set<int> _progressFieldIndexes = <int>{
  _statusFieldIndex,
  _stepsFieldIndex,
  _finishedAtFieldIndex,
};

ModelFieldValues _randomRunFields(Random random) {
  return <Object?>[
    randomRunId(random),
    randomTaskId(random),
    random.nextInt(_largestRunNumber),
    pickOne(random, RunStatus.values),
    randomRecordsOf(random, randomRunStep),
    randomRecordsOf(random, randomLogLine),
    randomRecordsOf(random, randomChatMessage),
    if (random.nextBool()) null else randomRunFailure(random),
    pickOne(random, RunnerLink.values),
    randomOptionalMoment(random),
    randomOptionalHostileText(random),
    randomOptionalHostileText(random),
    randomDeviceId(random),
    randomPreciseMoment(random),
    randomOptionalMoment(random),
    randomRecordsOf(random, randomLoopRounds),
    randomRecordsOf(random, randomRunNote),
  ];
}

Run _buildRun(ModelFieldValues fieldValues) {
  return Run(
    id: fieldValues[0]! as RunId,
    taskId: fieldValues[1]! as TaskId,
    number: fieldValues[2]! as int,
    status: fieldValues[_statusFieldIndex]! as RunStatus,
    steps: fieldValues[_stepsFieldIndex]! as List<RunStep>,
    log: fieldValues[_logFieldIndex]! as List<LogLine>,
    chat: fieldValues[_chatFieldIndex]! as List<ChatMessage>,
    failure: fieldValues[_failureFieldIndex] as RunFailure?,
    link: fieldValues[8]! as RunnerLink,
    linkLostAt: fieldValues[9] as DateTime?,
    agentSession: fieldValues[10] as String?,
    worktreeBranch: fieldValues[11] as String?,
    startedBy: fieldValues[12]! as DeviceId,
    startedAt: fieldValues[13]! as DateTime,
    finishedAt: fieldValues[_finishedAtFieldIndex] as DateTime?,
    loopRounds: fieldValues[_loopRoundsFieldIndex]! as List<LoopRounds>,
    notes: fieldValues[_notesFieldIndex]! as List<RunNote>,
  );
}

ModelFieldValues _readRunFields(Run run) {
  return <Object?>[
    run.id,
    run.taskId,
    run.number,
    run.status,
    run.steps,
    run.log,
    run.chat,
    run.failure,
    run.link,
    run.linkLostAt,
    run.agentSession,
    run.worktreeBranch,
    run.startedBy,
    run.startedAt,
    run.finishedAt,
    run.loopRounds,
    run.notes,
  ];
}

ModelFieldValues _readFieldsBesides(Run run, Set<int> changedIndexes) {
  final ModelFieldValues allFields = _readRunFields(run);
  final ModelFieldValues keptFields = <Object?>[];
  for (int i = 0; i < allFields.length; i += 1) {
    if (!changedIndexes.contains(i)) {
      keptFields.add(allFields[i]);
    }
  }
  return keptFields;
}

ModelFieldValues _readFieldsBesidesProgress(Run run) {
  return _readFieldsBesides(run, _progressFieldIndexes);
}

ModelFieldValues _readFieldsBesidesFailure(Run run) {
  return _readFieldsBesides(run, <int>{_failureFieldIndex});
}

RunFailure? _randomOptionalFailure(Random random) {
  if (random.nextBool()) {
    return null;
  }
  return randomRunFailure(random);
}

Run _runWithList(Random random, int listIndex, List<Object?> list) {
  final ModelFieldValues fieldValues = _randomRunFields(random);
  return _buildRun(<Object?>[
    for (int i = 0; i < fieldValues.length; i += 1)
      if (i == listIndex) list else fieldValues[i],
  ]);
}

void _testRunListCopy<Element>({
  required String fieldName,
  required int seed,
  required int listIndex,
  required Element Function(Random random) buildElement,
  required List<Element> Function(Run run) readList,
}) {
  testListCopyProperties(
    ListCopy<Run, Element>(
      testNamePrefix: 'test_run_constructor_property_$fieldName',
      seed: seed,
      buildElement: buildElement,
      construct: (Random random, List<Element> elements) =>
          _runWithList(random, listIndex, elements),
      readList: readList,
    ),
  );
}

void main() {
  testModelConstructorProperties(
    const ModelConstructor<Run>(
      testNamePrefix: 'test_run_constructor_property',
      seed: 691901,
      randomFieldValues: _randomRunFields,
      construct: _buildRun,
      readFieldValues: _readRunFields,
    ),
  );

  _testRunListCopy<RunStep>(
    fieldName: 'steps',
    seed: 691911,
    listIndex: _stepsFieldIndex,
    buildElement: randomRunStep,
    readList: (Run run) => run.steps,
  );
  _testRunListCopy<LogLine>(
    fieldName: 'log',
    seed: 691921,
    listIndex: _logFieldIndex,
    buildElement: randomLogLine,
    readList: (Run run) => run.log,
  );
  _testRunListCopy<ChatMessage>(
    fieldName: 'chat',
    seed: 691931,
    listIndex: _chatFieldIndex,
    buildElement: randomChatMessage,
    readList: (Run run) => run.chat,
  );
  _testRunListCopy<LoopRounds>(
    fieldName: 'loop_rounds',
    seed: 691941,
    listIndex: _loopRoundsFieldIndex,
    buildElement: randomLoopRounds,
    readList: (Run run) => run.loopRounds,
  );
  _testRunListCopy<RunNote>(
    fieldName: 'notes',
    seed: 691951,
    listIndex: _notesFieldIndex,
    buildElement: randomRunNote,
    readList: (Run run) => run.notes,
  );

  testModelCopyProperties(
    ModelCopy<Run, ModelFieldValues>(
      testNamePrefix: 'test_with_progress_property',
      seed: 691961,
      randomModel: (Random random) => _buildRun(_randomRunFields(random)),
      randomChange: (Random random) => <Object?>[
        pickOne(random, RunStatus.values),
        randomRecordsOf(random, randomRunStep),
        randomOptionalMoment(random),
      ],
      applyChange: (Run run, ModelFieldValues progress) => run.withProgress(
        nextStatus: progress[0]! as RunStatus,
        nextSteps: progress[1]! as List<RunStep>,
        nextFinishedAt: progress[2] as DateTime?,
      ),
      readChangedField: (Run run) => <Object?>[
        run.status,
        run.steps,
        run.finishedAt,
      ],
      readOtherFields: _readFieldsBesidesProgress,
    ),
  );

  testModelCopyProperties(
    ModelCopy<Run, RunFailure?>(
      testNamePrefix: 'test_with_failure_property',
      seed: 691971,
      randomModel: (Random random) => _buildRun(_randomRunFields(random)),
      randomChange: _randomOptionalFailure,
      applyChange: (Run run, RunFailure? failure) => run.withFailure(failure),
      readChangedField: (Run run) => run.failure,
      readOtherFields: _readFieldsBesidesFailure,
    ),
  );

  testNodeEnumMappingProperties(
    const NodeEnumMapping<RunStatus, node.RunStatus>(
      testNamePrefix: 'test_run_status_values_property',
      choices: RunStatus.values,
      nodeChoices: node.RunStatus.values,
      mapFromNode: mapRunStatusFromNode,
    ),
  );
}
