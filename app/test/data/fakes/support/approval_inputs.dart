import 'dart:math';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../../support/random_inputs.dart';
import 'notification_counter.dart';

const DeviceId approvalTestDevice = DeviceId('this-device');
const String _identifierPrefix = 'approval-';
const int _largestApprovalCount = 6;
const int _longestSequence = 8;

typedef CountedApprovals = ({
  FakeApprovalRepository repository,
  NotificationCounter notifications,
  DateTime moment,
});

SignedDecision randomSignedDecision(Random random) {
  return SignedDecision(
    decision: pickOne(random, ApprovalDecision.values),
    decidedBy: DeviceId(randomText(random)),
    decidedAt: randomUtcMoment(random),
    signature: const <int>[1, 2, 3],
  );
}

ApprovalRequest randomApprovalWithId(Random random, String identifier) {
  return ApprovalRequest(
    id: ApprovalId(identifier),
    runId: random.nextBool() ? null : RunId(randomText(random)),
    action: DeployAction(target: randomText(random)),
    requestedBy: DeviceId(randomText(random)),
    requestedAt: randomUtcMoment(random),
    decision: random.nextBool() ? null : randomSignedDecision(random),
  );
}

ApprovalRequest randomPendingApproval(Random random) {
  return ApprovalRequest(
    id: const ApprovalId('waiting'),
    runId: null,
    action: DeployAction(target: randomText(random)),
    requestedBy: DeviceId(randomText(random)),
    requestedAt: randomUtcMoment(random),
    decision: null,
  );
}

ApprovalRequest randomListedApproval(Random random) {
  return randomApprovalWithId(random, randomText(random));
}

List<ApprovalRequest> randomApprovals(Random random) {
  final List<ApprovalRequest> approvals = <ApprovalRequest>[];
  final int count = random.nextInt(_largestApprovalCount);
  for (int i = 0; i < count; i += 1) {
    approvals.add(randomApprovalWithId(random, '$_identifierPrefix$i'));
  }
  return approvals;
}

FakeApprovalRepository buildApprovalRepository(
  Random random,
  List<ApprovalRequest> approvals,
) {
  return FakeApprovalRepository(
    approvals: approvals,
    clock: FixedClock(randomUtcMoment(random)),
    currentDeviceId: approvalTestDevice,
  );
}

CountedApprovals buildCountedApprovals(
  Random random,
  List<ApprovalRequest> approvals,
) {
  final DateTime moment = randomUtcMoment(random);
  final FakeApprovalRepository repository = FakeApprovalRepository(
    approvals: approvals,
    clock: FixedClock(moment),
    currentDeviceId: approvalTestDevice,
  );
  final NotificationCounter notifications = NotificationCounter();
  repository.addListener(notifications.record);
  return (
    repository: repository,
    notifications: notifications,
    moment: moment,
  );
}

Future<void> decideRandomPendingApprovals(
  Random random,
  FakeApprovalRepository repository,
) async {
  final int count = random.nextInt(_longestSequence);
  for (int i = 0; i < count; i += 1) {
    final List<ApprovalRequest> pending = repository.listPendingApprovals();
    if (pending.isEmpty) {
      return;
    }
    await repository.decideApproval(
      pickOne(random, pending).id,
      pickOne(random, ApprovalDecision.values),
    );
  }
}
