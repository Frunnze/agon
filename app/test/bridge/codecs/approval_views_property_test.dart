import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/approval_views.dart';
import 'package:agent_orchestration/bridge/codecs/workflow_views.dart';

import '../../support/random_inputs.dart';
import '../support/list_copy_properties.dart';
import '../support/random_run_json.dart';
import '../support/random_work_json.dart';
import '../support/wire_codec_properties.dart';

const List<WireCodec> _approvalViewCodecs = <WireCodec>[
  WireCodec(
    typeName: 'skill_change_view',
    seed: 49500,
    buildJson: randomSkillChangeViewJson,
    decode: SkillChangeView.fromJson,
    requiredFields: <String>{'skill_name', 'changes'},
    optionalFields: <String>{},
  ),
  WireCodec(
    typeName: 'approval_view',
    seed: 49510,
    buildJson: randomApprovalViewJson,
    decode: ApprovalView.fromJson,
    requiredFields: <String>{'approval', 'description', 'is_waiting'},
    optionalFields: <String>{'skill_change'},
  ),
  WireCodec(
    typeName: 'approvals_view',
    seed: 49520,
    buildJson: randomApprovalsViewJson,
    decode: ApprovalsView.fromJson,
    requiredFields: <String>{'waiting_count', 'approvals'},
    optionalFields: <String>{},
  ),
];

void main() {
  for (final WireCodec codec in _approvalViewCodecs) {
    testWireDecodingProperties(codec);
    testWireEncodingProperties(codec);
  }

  testListCopyProperties(
    const ListCopy<SkillChangeView, DiffLine>(
      testNamePrefix: 'test_skill_change_view_constructor_property_changes',
      seed: 49530,
      buildElement: _buildDiffLine,
      construct: _buildSkillChangeView,
      readList: _readChanges,
    ),
  );

  testListCopyProperties(
    const ListCopy<ApprovalsView, ApprovalView>(
      testNamePrefix: 'test_approvals_view_constructor_property_approvals',
      seed: 49540,
      buildElement: _buildApprovalView,
      construct: _buildApprovalsView,
      readList: _readApprovals,
    ),
  );
}

DiffLine _buildDiffLine(Random random) {
  return DiffLine.fromJson(randomDiffLineJson(random));
}

SkillChangeView _buildSkillChangeView(Random random, List<DiffLine> changes) {
  return SkillChangeView(skillName: randomText(random), changes: changes);
}

List<DiffLine> _readChanges(SkillChangeView view) => view.changes;

ApprovalView _buildApprovalView(Random random) {
  return ApprovalView.fromJson(randomApprovalViewJson(random));
}

ApprovalsView _buildApprovalsView(
  Random random,
  List<ApprovalView> approvals,
) {
  return ApprovalsView(
    waitingCount: random.nextInt(approvals.length + 1),
    approvals: approvals,
  );
}

List<ApprovalView> _readApprovals(ApprovalsView view) => view.approvals;
