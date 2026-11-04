import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/presentation/approval_policy_text.dart';
import 'package:agent_orchestration/screens/shared/approval_policy_field.dart';
import 'package:agent_orchestration/screens/shared/muted_note.dart';
import 'package:agent_orchestration/widgets/forms/choice_list_field.dart';
import 'package:agent_orchestration/widgets/page_section.dart';

class WorkspaceApprovalPolicySection extends StatelessWidget {
  const WorkspaceApprovalPolicySection({
    required this.workspaceRepository,
    super.key,
  });

  final WorkspaceRepository workspaceRepository;

  @override
  Widget build(BuildContext context) {
    final Workspace workspace = workspaceRepository.currentWorkspace();

    return PageSection(
      title: approvalPolicyLabel,
      children: <Widget>[
        ChoiceListField<ApprovalPolicy>(
          options: buildApprovalPolicyChoices(),
          selected: workspace.approvalPolicy,
          onChanged: (ApprovalPolicy policy) =>
              _changeApprovalPolicy(workspace, policy),
        ),
        const MutedNote(workspaceApprovalPolicyNote),
      ],
    );
  }

  void _changeApprovalPolicy(Workspace workspace, ApprovalPolicy policy) {
    unawaited(
      workspaceRepository.changeApprovalPolicy(
        workspaceId: workspace.id,
        approvalPolicy: policy,
      ),
    );
  }
}
