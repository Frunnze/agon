import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/run_values.dart' as node;
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../bridge/support/list_copy_properties.dart';
import '../../bridge/support/random_typed_values.dart';
import '../../support/random_inputs.dart';
import 'support/domain_model_properties.dart';
import 'support/random_run_records.dart';

ModelFieldValues _randomStepFields(Random random) {
  return <Object?>[
    randomHostileText(random),
    if (random.nextBool())
      null
    else
      WorkflowAgentId(randomHostileText(random)),
    if (random.nextBool()) null else randomDeviceId(random),
    pickOne(random, StepStatus.values),
    randomOptionalMoment(random),
    randomOptionalMoment(random),
    randomOptionalHostileText(random),
    randomOptionalHostileText(random),
    randomOptionalHostileText(random),
    randomRecordsOf(random, randomEarlierRound),
  ];
}

RunStep _buildStep(ModelFieldValues fieldValues) {
  return RunStep(
    name: fieldValues[0]! as String,
    agentId: fieldValues[1] as WorkflowAgentId?,
    runner: fieldValues[2] as DeviceId?,
    status: fieldValues[3]! as StepStatus,
    startedAt: fieldValues[4] as DateTime?,
    finishedAt: fieldValues[5] as DateTime?,
    result: fieldValues[6] as String?,
    outcome: fieldValues[7] as String?,
    loopSource: fieldValues[8] as String?,
    earlierRounds: fieldValues[9]! as List<EarlierRound>,
  );
}

ModelFieldValues _readStepFields(RunStep step) {
  return <Object?>[
    step.name,
    step.agentId,
    step.runner,
    step.status,
    step.startedAt,
    step.finishedAt,
    step.result,
    step.outcome,
    step.loopSource,
    step.earlierRounds,
  ];
}

ModelFieldValues _readStepFieldsBesidesStatus(RunStep step) {
  return <Object?>[
    step.name,
    step.agentId,
    step.runner,
    step.startedAt,
    step.finishedAt,
    step.result,
    step.outcome,
    step.loopSource,
    step.earlierRounds,
  ];
}

void main() {
  testModelConstructorProperties(
    ModelConstructor<EarlierRound>(
      testNamePrefix: 'test_earlier_round_constructor_property',
      seed: 691701,
      randomFieldValues: (Random random) => <Object?>[
        pickOne(random, StepStatus.values),
        randomOptionalMoment(random),
        randomOptionalMoment(random),
        randomOptionalHostileText(random),
        randomOptionalHostileText(random),
      ],
      construct: (ModelFieldValues fieldValues) => EarlierRound(
        status: fieldValues[0]! as StepStatus,
        startedAt: fieldValues[1] as DateTime?,
        finishedAt: fieldValues[2] as DateTime?,
        result: fieldValues[3] as String?,
        outcome: fieldValues[4] as String?,
      ),
      readFieldValues: (EarlierRound round) => <Object?>[
        round.status,
        round.startedAt,
        round.finishedAt,
        round.result,
        round.outcome,
      ],
    ),
  );

  testModelConstructorProperties(
    const ModelConstructor<RunStep>(
      testNamePrefix: 'test_run_step_constructor_property',
      seed: 691711,
      randomFieldValues: _randomStepFields,
      construct: _buildStep,
      readFieldValues: _readStepFields,
    ),
  );

  testListCopyProperties(
    ListCopy<RunStep, EarlierRound>(
      testNamePrefix: 'test_run_step_constructor_property_earlier_rounds',
      seed: 691721,
      buildElement: randomEarlierRound,
      construct: (Random random, List<EarlierRound> rounds) => RunStep(
        name: randomHostileText(random),
        agentId: null,
        runner: random.nextBool() ? null : randomDeviceId(random),
        status: pickOne(random, StepStatus.values),
        startedAt: randomOptionalMoment(random),
        finishedAt: randomOptionalMoment(random),
        result: null,
        outcome: null,
        loopSource: null,
        earlierRounds: rounds,
      ),
      readList: (RunStep step) => step.earlierRounds,
    ),
  );

  testModelCopyProperties(
    ModelCopy<RunStep, StepStatus>(
      testNamePrefix: 'test_with_status_property',
      seed: 691731,
      randomModel: randomRunStep,
      randomChange: (Random random) => pickOne(random, StepStatus.values),
      applyChange: (RunStep step, StepStatus status) =>
          step.withStatus(status),
      readChangedField: (RunStep step) => step.status,
      readOtherFields: _readStepFieldsBesidesStatus,
    ),
  );

  testNodeEnumMappingProperties(
    const NodeEnumMapping<StepStatus, node.StepStatus>(
      testNamePrefix: 'test_step_status_values_property',
      choices: StepStatus.values,
      nodeChoices: node.StepStatus.values,
      mapFromNode: mapStepStatusFromNode,
    ),
  );
}
