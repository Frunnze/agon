import 'package:agent_orchestration/data/gallery/gallery_chat.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';

const String gallerySessionId = '7c1e3f5a9b2d4e6f8a1c3e5b7d9fa90f';
const String _buildStepName = 'build-ios';
const String _claudeCodeStepName = 'claude-code';
const String _geminiCliStepName = 'gemini-cli';
const String galleryKeptBranch = 'task/rename-the-billing-module-7b3e';
const String galleryShipRelease24Branch = 'task/ship-release-2-4-9e07';
const String galleryShipRelease23Branch = 'task/ship-release-2-3-5c18';

WorkflowAgentId _releaseAgentId(int index) => releaseAgents[index].id;

LogLine _buildLogLine(DateTime at, String text) {
  return LogLine(at: at, stepName: _buildStepName, text: text, isError: false);
}

LogLine _buildErrorLine(DateTime at, String text) {
  return LogLine(at: at, stepName: _buildStepName, text: text, isError: true);
}

LogLine _buildAgentLine(DateTime at, String text) {
  return LogLine(
    at: at,
    stepName: _claudeCodeStepName,
    text: text,
    isError: false,
  );
}

final Run galleryRunningRun = Run(
  id: GalleryRunIds.release42,
  taskId: GalleryTaskIds.shipRelease24,
  number: 42,
  status: RunStatus.running,
  steps: <RunStep>[
    RunStep(
      name: 'plan',
      agentId: _releaseAgentId(0),
      runner: GalleryDeviceIds.officeServer,
      status: StepStatus.done,
      startedAt: galleryToday(14, 3, 30),
      finishedAt: galleryToday(14, 5, 40),
      result: null,
      outcome: null,
      loopSource: null,
      earlierRounds: const <EarlierRound>[],
    ),
    RunStep(
      name: _buildStepName,
      agentId: _releaseAgentId(1),
      runner: GalleryDeviceIds.macStudio,
      status: StepStatus.running,
      startedAt: galleryToday(14, 5, 40),
      finishedAt: null,
      result: null,
      outcome: null,
      loopSource: null,
      earlierRounds: const <EarlierRound>[],
    ),
    RunStep(
      name: 'train',
      agentId: _releaseAgentId(2),
      runner: null,
      status: StepStatus.waiting,
      startedAt: null,
      finishedAt: null,
      result: null,
      outcome: null,
      loopSource: null,
      earlierRounds: const <EarlierRound>[],
    ),
  ],
  log: <LogLine>[
    _buildLogLine(galleryToday(14, 2, 11), 'Cloned acme/app into /workspace'),
    _buildLogLine(
      galleryToday(14, 2, 19),
      'Sandbox ready: new container, network allowlist on',
    ),
    _buildLogLine(
      galleryToday(14, 2, 20),
      'Agent started: claude, session 7c1e…a90f',
    ),
    _buildLogLine(
      galleryToday(14, 3, 2),
      'Ran xcodebuild -scheme App -configuration Release',
    ),
    _buildLogLine(galleryToday(14, 5, 40), 'Compiling 214 of 388 files'),
  ],
  chat: galleryRunChat,
  failure: null,
  link: RunnerLink.direct,
  linkLostAt: null,
  agentSession: gallerySessionId,
  worktreeBranch: galleryShipRelease24Branch,
  startedBy: GalleryDeviceIds.airLaptop,
  startedAt: galleryToday(14, 5, 40),
  finishedAt: null,
  loopRounds: const <LoopRounds>[],
  notes: const <RunNote>[],
);

final Run galleryFailedRun = Run(
  id: GalleryRunIds.release41,
  taskId: GalleryTaskIds.shipRelease23,
  number: 41,
  status: RunStatus.failed,
  steps: <RunStep>[
    RunStep(
      name: 'plan',
      agentId: _releaseAgentId(0),
      runner: GalleryDeviceIds.officeServer,
      status: StepStatus.done,
      startedAt: galleryYesterday(18, 20),
      finishedAt: galleryYesterday(18, 22, 4),
      result: null,
      outcome: null,
      loopSource: null,
      earlierRounds: const <EarlierRound>[],
    ),
    RunStep(
      name: _buildStepName,
      agentId: _releaseAgentId(1),
      runner: GalleryDeviceIds.macStudio,
      status: StepStatus.failed,
      startedAt: galleryYesterday(18, 28, 2),
      finishedAt: galleryYesterday(18, 31, 14),
      result: null,
      outcome: null,
      loopSource: null,
      earlierRounds: const <EarlierRound>[],
    ),
    RunStep(
      name: 'train',
      agentId: _releaseAgentId(2),
      runner: null,
      status: StepStatus.skipped,
      startedAt: null,
      finishedAt: galleryYesterday(18, 31, 14),
      result: null,
      outcome: null,
      loopSource: null,
      earlierRounds: const <EarlierRound>[],
    ),
  ],
  log: <LogLine>[
    _buildLogLine(
      galleryYesterday(18, 28, 2),
      'Ran xcodebuild -scheme App -configuration Release',
    ),
    _buildLogLine(galleryYesterday(18, 31, 10), 'Signing App.app for Release'),
    _buildErrorLine(
      galleryYesterday(18, 31, 14),
      'error: No signing certificate "Apple Distribution" found',
    ),
    _buildErrorLine(
      galleryYesterday(18, 31, 14),
      '** ARCHIVE FAILED ** (exit code 65)',
    ),
  ],
  chat: const <ChatMessage>[],
  failure: const RunFailure(
    stepName: _buildStepName,
    runner: GalleryDeviceIds.macStudio,
    reason:
        'xcodebuild stopped with code 65: no "Apple Distribution" '
        'signing certificate on this runner.',
    retryRunsOnSameRunner: true,
  ),
  link: RunnerLink.direct,
  linkLostAt: null,
  agentSession: null,
  worktreeBranch: galleryShipRelease23Branch,
  startedBy: GalleryDeviceIds.airLaptop,
  startedAt: galleryYesterday(18, 20),
  finishedAt: galleryYesterday(18, 31, 14),
  loopRounds: const <LoopRounds>[],
  notes: const <RunNote>[],
);

final Run galleryFinishedRun = Run(
  id: GalleryRunIds.writeApiDocs1,
  taskId: GalleryTaskIds.writeApiDocs,
  number: 1,
  status: RunStatus.done,
  steps: <RunStep>[
    RunStep(
      name: _geminiCliStepName,
      agentId: null,
      runner: GalleryDeviceIds.officeServer,
      status: StepStatus.done,
      startedAt: galleryYesterday(11, 40),
      finishedAt: galleryYesterday(11, 58),
      result: null,
      outcome: null,
      loopSource: null,
      earlierRounds: const <EarlierRound>[],
    ),
  ],
  log: const <LogLine>[],
  chat: const <ChatMessage>[],
  failure: null,
  link: RunnerLink.direct,
  linkLostAt: null,
  agentSession: null,
  worktreeBranch: 'task/write-the-v2-api-docs',
  startedBy: GalleryDeviceIds.airLaptop,
  startedAt: galleryYesterday(11, 40),
  finishedAt: galleryYesterday(11, 58),
  loopRounds: const <LoopRounds>[],
  notes: const <RunNote>[],
);

final Run galleryNotPushedRun = Run(
  id: GalleryRunIds.renameBillingModule1,
  taskId: GalleryTaskIds.renameBillingModule,
  number: 1,
  status: RunStatus.done,
  steps: <RunStep>[
    RunStep(
      name: _claudeCodeStepName,
      agentId: null,
      runner: GalleryDeviceIds.officeServer,
      status: StepStatus.done,
      startedAt: galleryTwoDaysAgo(14, 9, 40),
      finishedAt: galleryTwoDaysAgo(14, 25, 10),
      result: null,
      outcome: null,
      loopSource: null,
      earlierRounds: const <EarlierRound>[],
    ),
  ],
  log: <LogLine>[
    _buildAgentLine(
      galleryTwoDaysAgo(14, 9, 52),
      'Agent started: claude, session 3b9d…c1e2',
    ),
    _buildAgentLine(
      galleryTwoDaysAgo(14, 20, 31),
      'Renamed billing to payments in 14 files',
    ),
    _buildAgentLine(
      galleryTwoDaysAgo(14, 21, 58),
      'Committed the rename on $galleryKeptBranch',
    ),
  ],
  chat: const <ChatMessage>[],
  failure: null,
  link: RunnerLink.direct,
  linkLostAt: null,
  agentSession: null,
  worktreeBranch: galleryKeptBranch,
  startedBy: GalleryDeviceIds.airLaptop,
  startedAt: galleryTwoDaysAgo(14, 9, 40),
  finishedAt: galleryTwoDaysAgo(14, 25, 10),
  loopRounds: const <LoopRounds>[],
  notes: const <RunNote>[],
);

final List<Run> galleryRuns = List<Run>.unmodifiable(<Run>[
  galleryRunningRun,
  galleryFailedRun,
  galleryFinishedRun,
  galleryNotPushedRun,
]);
