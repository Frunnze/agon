import 'package:agent_orchestration/data/models/approval.dart';

const String approvalPolicyLabel = 'Commands';

String describeApprovalPolicyTitle(ApprovalPolicy policy) {
  return switch (policy) {
    ApprovalPolicy.askBeforeRiskyActions => 'Ask for approval',
    ApprovalPolicy.neverAsk => 'Auto',
  };
}

String describeApprovalPolicyDetail(ApprovalPolicy policy) {
  return switch (policy) {
    ApprovalPolicy.askBeforeRiskyActions =>
      'It asks you before each command and each push.',
    ApprovalPolicy.neverAsk =>
      'It runs commands and pushes without asking, and refuses risky '
          'commands. In Docker it can run anything.',
  };
}
