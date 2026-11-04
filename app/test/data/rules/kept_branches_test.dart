import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_approvals.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_runs.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/rules/kept_branches.dart';

import '../../support/random_inputs.dart';
import '../../support/sample_folder_paths.dart';

final List<String> _repositories = <String>[
  'github.com/acme/app',
  'github.com/acme/api',
  'local:9c7a5e3b:${buildTemporaryFolderPath('hello-counter')}',
];
const List<String> _branches = <String>[
  'task/rename-the-billing-module-7b3e',
  'task/ship-release-2-4',
  'task/write-tests-run-3',
];
const List<DeviceId> _runners = <DeviceId>[
  GalleryDeviceIds.officeServer,
  GalleryDeviceIds.macStudio,
];
const RunId _otherRunId = RunId('run-somewhere-else');
const int _mostApprovals = 8;

Run _runWithStatus(RunStatus status) {
  return galleryFinishedRun.withProgress(
    nextStatus: status,
    nextSteps: galleryFinishedRun.steps,
    nextFinishedAt: galleryFinishedRun.finishedAt,
  );
}

SignedDecision? _randomDecision(Random random) {
  final ApprovalDecision? decision = pickOne(random, <ApprovalDecision?>[
    null,
    ApprovalDecision.approved,
    ApprovalDecision.denied,
  ]);
  if (decision == null) {
    return null;
  }
  return SignedDecision(
    decision: decision,
    decidedBy: GalleryDeviceIds.airLaptop,
    decidedAt: randomUtcMoment(random),
    signature: const <int>[0],
  );
}

ApprovalRequest _randomPush(Random random, RunId runId, int index) {
  return ApprovalRequest(
    id: ApprovalId('approval-$index'),
    runId: runId,
    action: PushCommitsAction(
      repository: pickOne(random, _repositories),
      branch: pickOne(random, _branches),
      commits: <String>[randomWordPhrase(random)],
    ),
    requestedBy: pickOne(random, _runners),
    requestedAt: randomUtcMoment(random),
    decision: _randomDecision(random),
  );
}

ApprovalRequest _randomNoise(Random random, RunId runId, int index) {
  final bool isPushOfOtherRun = random.nextBool();
  final ApprovalAction action = isPushOfOtherRun
      ? PushCommitsAction(
          repository: pickOne(random, _repositories),
          branch: pickOne(random, _branches),
          commits: const <String>[],
        )
      : DeployAction(target: randomWordPhrase(random));

  return ApprovalRequest(
    id: ApprovalId('noise-$index'),
    runId: isPushOfOtherRun ? _otherRunId : runId,
    action: action,
    requestedBy: pickOne(random, _runners),
    requestedAt: randomUtcMoment(random),
    decision: _randomDecision(random),
  );
}

List<ApprovalRequest> _randomPushes(Random random, RunId runId) {
  final int count = random.nextInt(_mostApprovals);
  return <ApprovalRequest>[
    for (int i = 0; i < count; i += 1) _randomPush(random, runId, i),
  ];
}

ApprovalDecision? _lastDecisionFor(
  List<ApprovalRequest> approvals,
  String repository,
) {
  ApprovalDecision? last;
  for (final ApprovalRequest approval in approvals) {
    final ApprovalAction action = approval.action;
    final SignedDecision? decision = approval.decision;
    final bool isDecidedPush =
        action is PushCommitsAction &&
        action.repository == repository &&
        decision != null;
    if (isDecidedPush) {
      last = decision.decision;
    }
  }
  return last;
}

bool _matchesDeniedPush(KeptBranch kept, List<ApprovalRequest> approvals) {
  for (final ApprovalRequest approval in approvals) {
    final ApprovalAction action = approval.action;
    final bool isMatch =
        action is PushCommitsAction &&
        action.repository == kept.repositoryAddress &&
        action.branch == kept.branch &&
        approval.requestedBy == kept.runner &&
        approval.decision?.decision == ApprovalDecision.denied;
    if (isMatch) {
      return true;
    }
  }
  return false;
}

List<String> _keptRepositories(List<KeptBranch> keptBranches) {
  return <String>[
    for (final KeptBranch kept in keptBranches) kept.repositoryAddress,
  ];
}

void main() {
  test('test_find_kept_branches_property_keeps_only_denied_pushes', () {
    final Random random = seededRandom(91);
    final Run run = _runWithStatus(RunStatus.done);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<ApprovalRequest> approvals = _randomPushes(random, run.id);

      final List<KeptBranch> keptBranches = findKeptBranches(
        run: run,
        approvals: approvals,
      );

      for (final KeptBranch kept in keptBranches) {
        expect(_matchesDeniedPush(kept, approvals), isTrue);
      }
    }
  });

  test('test_find_kept_branches_property_follows_the_last_decision', () {
    final Random random = seededRandom(92);
    final Run run = _runWithStatus(RunStatus.done);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<ApprovalRequest> approvals = _randomPushes(random, run.id);

      final List<String> kept = _keptRepositories(
        findKeptBranches(run: run, approvals: approvals),
      );

      for (final String repository in _repositories) {
        final bool isDenied =
            _lastDecisionFor(approvals, repository) == ApprovalDecision.denied;
        expect(kept.contains(repository), isDenied, reason: repository);
      }
      expect(kept.toSet().length, kept.length);
    }
  });

  test('test_find_kept_branches_property_ignores_other_runs_and_actions', () {
    final Random random = seededRandom(93);
    final Run run = _runWithStatus(RunStatus.done);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<ApprovalRequest> approvals = _randomPushes(random, run.id);
      final List<ApprovalRequest> withNoise = <ApprovalRequest>[
        for (final ApprovalRequest approval in approvals) ...<ApprovalRequest>[
          _randomNoise(random, run.id, i),
          approval,
        ],
      ];

      final List<KeptBranch> plain = findKeptBranches(
        run: run,
        approvals: approvals,
      );
      final List<KeptBranch> noisy = findKeptBranches(
        run: run,
        approvals: withNoise,
      );

      expect(_keptRepositories(noisy), _keptRepositories(plain));
    }
  });

  test('test_find_kept_branches_property_only_done_runs_keep_branches', () {
    final Random random = seededRandom(94);
    final List<RunStatus> notDone = <RunStatus>[
      for (final RunStatus status in RunStatus.values)
        if (status != RunStatus.done) status,
    ];

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = _runWithStatus(pickOne(random, notDone));
      final List<ApprovalRequest> approvals = _randomPushes(random, run.id);

      expect(findKeptBranches(run: run, approvals: approvals), isEmpty);
    }
  });

  test('a denied push of the gallery run keeps its task branch', () {
    final List<KeptBranch> keptBranches = findKeptBranches(
      run: galleryNotPushedRun,
      approvals: <ApprovalRequest>[galleryDeniedPushApproval],
    );

    expect(keptBranches.single.repositoryAddress, 'github.com/acme/app');
    expect(keptBranches.single.branch, 'task/rename-the-billing-module-7b3e');
    expect(keptBranches.single.runner, GalleryDeviceIds.officeServer);
  });
}
