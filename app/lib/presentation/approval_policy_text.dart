import 'package:agent_orchestration/data/models/approval.dart';

const String approvalPolicyLabel = 'Commands and pushes';
const String workspaceApprovalPolicyNote =
    'Projects, tasks and steps follow this unless they choose their own.';

const List<ApprovalPolicy> approvalPolicyChoiceOrder = <ApprovalPolicy>[
  ApprovalPolicy.neverAsk,
  ApprovalPolicy.askBeforeRiskyActions,
];

enum ApprovalPolicyFallback {
  project(
    title: 'Same as the project',
    detail: "Uses the project's setting, or the workspace's.",
  ),
  workspace(
    title: 'Same as the workspace',
    detail: 'Uses the workspace setting in Settings.',
  );

  const ApprovalPolicyFallback({required this.title, required this.detail});

  final String title;
  final String detail;
}

String describeApprovalPolicyTitle(ApprovalPolicy policy) {
  return switch (policy) {
    ApprovalPolicy.neverAsk => 'Auto',
    ApprovalPolicy.askBeforeRiskyActions => 'Ask me',
  };
}

String describeApprovalPolicyDetail(ApprovalPolicy policy) {
  return switch (policy) {
    ApprovalPolicy.neverAsk => 'Runs commands and pushes without asking you.',
    ApprovalPolicy.askBeforeRiskyActions =>
      'Asks you before each command and each push.',
  };
}
