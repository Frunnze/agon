import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/device_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/live_run_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/run_chat_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/run_values.dart' as node;
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';

import '../../../../bridge/support/hostile_texts.dart';
import '../../../../bridge/support/random_moments.dart';
import '../../../../support/random_inputs.dart';
import '../../../models/support/random_run_records.dart';
import '../../../rules/support/random_progress_runs.dart';

const int largestSequenceLength = 14;
const List<DeviceId> _freshRunners = <DeviceId>[
  holdingRunner,
  holdingRunner,
  holdingRunner,
  otherRunner,
];

Run freshHeldRun(Random random) {
  final int stepCount = 1 + random.nextInt(largestProgressStepCount);
  final List<RunStep> steps = <RunStep>[
    for (int index = 0; index < stepCount; index += 1)
      RunStep(
        name: 'step $index ${randomHostileText(random)}',
        agentId: null,
        runner: pickOne(random, _freshRunners),
        status: StepStatus.waiting,
        startedAt: null,
        finishedAt: null,
        result: null,
        outcome: null,
        loopSource: null,
        earlierRounds: const <EarlierRound>[],
      ),
  ];
  final Run template = buildProgressRun(
    random,
    status: RunStatus.queued,
    steps: steps,
  );
  return Run(
    id: template.id,
    taskId: template.taskId,
    number: template.number,
    status: RunStatus.queued,
    steps: steps,
    log: template.log,
    chat: template.chat,
    failure: null,
    link: template.link,
    linkLostAt: template.linkLostAt,
    agentSession: template.agentSession,
    worktreeBranch: template.worktreeBranch,
    startedBy: template.startedBy,
    startedAt: template.startedAt,
    finishedAt: null,
    loopRounds: template.loopRounds,
    notes: template.notes,
  );
}

node.StepStatusChanged buildStatusEvent(String stepName, StepStatus status) {
  return node.StepStatusChanged(
    stepName: stepName,
    status: node.StepStatus.values.byName(status.name),
  );
}

node.RunFailed buildFailureEvent(Random random, String stepName) {
  return node.RunFailed(
    failure: node.RunFailure(
      stepName: stepName,
      runner: null,
      reason: randomHostileText(random),
      retryRunsOnSameRunner: random.nextBool(),
    ),
  );
}

node.ChatAppended buildNewChatEvent(
  Random random,
  int position,
  node.ChatAuthor author,
) {
  return node.ChatAppended(
    message: node.ChatMessage(
      at: randomPreciseMoment(random),
      author: author,
      text: 'message $position ${randomHostileText(random)}',
      isError: random.nextBool(),
      waitingToSend: random.nextBool(),
    ),
  );
}

node.RunEvent randomServerEvent(Random random, Run run, int position) {
  final String stepName = randomStepNameOf(random, run);
  return switch (random.nextInt(10)) {
    0 ||
    1 ||
    2 => buildStatusEvent(stepName, pickOne(random, StepStatus.values)),
    3 => node.LogAppended(
      line: node.LogLine(
        at: randomPreciseMoment(random),
        stepName: stepName,
        text: 'line $position ${randomHostileText(random)}',
        isError: random.nextBool(),
      ),
    ),
    4 => buildNewChatEvent(
      random,
      position,
      pickOne(random, node.ChatAuthor.values),
    ),
    5 => node.SessionStarted(session: randomHostileText(random)),
    6 => buildFailureEvent(random, stepName),
    7 => node.StepResultRecorded(
      stepName: stepName,
      result: randomHostileText(random),
      outcome: randomOptionalHostileText(random),
    ),
    8 => const node.RunFinished(),
    _ => node.LinkChanged(link: pickOne(random, node.RunnerLink.values)),
  };
}
