import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/presentation/approval_policy_text.dart';

void main() {
  test('test_describe_approval_policy_title_property_ask_or_auto', () {
    expect(
      describeApprovalPolicyTitle(ApprovalPolicy.askBeforeRiskyActions),
      'Ask for approval',
    );
    expect(describeApprovalPolicyTitle(ApprovalPolicy.neverAsk), 'Auto');
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
      describeApprovalPolicyDetail(ApprovalPolicy.askBeforeRiskyActions),
      contains('asks you before each command'),
    );
    expect(
      describeApprovalPolicyDetail(ApprovalPolicy.neverAsk),
      contains('without asking'),
    );
  });
}
