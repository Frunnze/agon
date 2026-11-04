import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/presentation/approval_policy_text.dart';

void main() {
  test('test_describe_approval_policy_title_property_auto_or_ask_me', () {
    expect(describeApprovalPolicyTitle(ApprovalPolicy.neverAsk), 'Auto');
    expect(
      describeApprovalPolicyTitle(ApprovalPolicy.askBeforeRiskyActions),
      'Ask me',
    );
  });

  test('test_describe_approval_policy_detail_property_one_line_each', () {
    final Set<String> details = <String>{};
    for (final ApprovalPolicy policy in ApprovalPolicy.values) {
      final String detail = describeApprovalPolicyDetail(policy);

      expect(detail, endsWith('.'));
      expect(detail, isNot(contains('\n')));
      details.add(detail);
    }

    expect(details.length, ApprovalPolicy.values.length);
    expect(
      describeApprovalPolicyDetail(ApprovalPolicy.neverAsk),
      'Runs commands and pushes without asking you.',
    );
    expect(
      describeApprovalPolicyDetail(ApprovalPolicy.askBeforeRiskyActions),
      'Asks you before each command and each push.',
    );
  });

  test('test_approval_policy_choice_order_property_auto_first_once_each', () {
    expect(approvalPolicyChoiceOrder.first, ApprovalPolicy.neverAsk);
    expect(approvalPolicyChoiceOrder.toSet(), ApprovalPolicy.values.toSet());
    expect(approvalPolicyChoiceOrder.length, ApprovalPolicy.values.length);
  });

  test('test_approval_policy_fallback_property_names_the_level_above', () {
    expect(ApprovalPolicyFallback.project.title, 'Same as the project');
    expect(
      ApprovalPolicyFallback.project.detail,
      "Uses the project's setting, or the workspace's.",
    );
    expect(ApprovalPolicyFallback.workspace.title, 'Same as the workspace');
    expect(
      ApprovalPolicyFallback.workspace.detail,
      'Uses the workspace setting in Settings.',
    );
  });
}
