import 'package:flutter/material.dart';

import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/local_folder_address.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';
import 'package:agent_orchestration/screens/approvals/approval_text.dart';
import 'package:agent_orchestration/screens/workflows/document_lines.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/app_dialog.dart';
import 'package:agent_orchestration/widgets/code_block.dart';
import 'package:agent_orchestration/widgets/fact_list.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/presentation/device_names.dart';

const Map<String, String> _hostLabels = <String, String>{
  'github.com': 'GitHub',
  'gitlab.com': 'GitLab',
  'bitbucket.org': 'Bitbucket',
};

String describePushDestination(String repositoryAddress) {
  if (parseLocalFolderAddress(repositoryAddress) != null) {
    return describeRepositoryPath(repositoryAddress);
  }
  final String host = repositoryAddress.split('/').first;

  return _hostLabels[host] ?? host;
}

class ApprovalDialog extends StatelessWidget {
  const ApprovalDialog({
    required this.request,
    required this.runLabel,
    required this.askedBy,
    required this.workflows,
    required this.deviceNames,
    super.key,
  });

  final ApprovalRequest request;
  final String? runLabel;
  final String askedBy;
  final List<Workflow> workflows;
  final DeviceNames deviceNames;

  @override
  Widget build(BuildContext context) {
    final ApprovalAction action = request.action;
    final Fact askedByFact = Fact(
      term: 'Asked by',
      description: <TextSegment>[TextSegment(askedBy)],
    );

    if (action is PushCommitsAction) {
      return AppDialog(
        title: '${describePushTitle(action)}?',
        content: <Widget>[
          Text(
            describePushRequest(
              runLabel: runLabel,
              commitCount: action.commits.length,
            ),
          ),
          FactList(
            facts: <Fact>[
              Fact(
                term: 'Repository',
                description: <TextSegment>[
                  TextSegment.monospace(
                    describeApprovalRepository(action.repository, deviceNames),
                  ),
                ],
              ),
              Fact(
                term: 'Branch',
                description: <TextSegment>[
                  TextSegment.monospace(action.branch),
                ],
              ),
              askedByFact,
            ],
          ),
          CodeBlock(
            lines: <CodeBlockLine>[
              for (final String commit in action.commits)
                CodeBlockLine(commit),
            ],
          ),
          const DialogNote(
            'The hub makes the push outside the sandbox. The agent never '
            'holds write access to the repository.',
          ),
        ],
        actions: _buildDecisionButtons(context),
      );
    }

    if (action is RunCommandAction) {
      return _buildCommandDialog(context, action, askedByFact);
    }

    if (action is ImproveSkillAction) {
      return _buildSkillChangeDialog(context, action, askedByFact);
    }

    return AppDialog(
      title: '${describeApprovalTitle(action, workflows)}?',
      content: <Widget>[
        Text(describeActionRequest(runLabel: runLabel)),
        FactList(facts: <Fact>[askedByFact]),
      ],
      actions: _buildDecisionButtons(context),
    );
  }

  Widget _buildCommandDialog(
    BuildContext context,
    RunCommandAction action,
    Fact askedByFact,
  ) {
    final String request = describeToolUseRequest(
      runLabel: runLabel,
      tool: action.tool,
    );

    return AppDialog(
      title: '${action.summary}?',
      content: <Widget>[
        Text(request),
        FactList(facts: <Fact>[askedByFact]),
        WrappedCodeBlock(text: action.command),
        const DialogNote('The run waits until you decide.'),
      ],
      actions: _buildDecisionButtons(context),
    );
  }

  Widget _buildSkillChangeDialog(
    BuildContext context,
    ImproveSkillAction action,
    Fact askedByFact,
  ) {
    final SkillChangePreview? preview = action.preview;
    final Fact changeFact = Fact(
      term: 'Change',
      description: <TextSegment>[TextSegment(action.summary)],
    );

    return AppDialog(
      title: '${describeApprovalTitle(action, workflows)}?',
      content: <Widget>[
        Text(describeSkillChangeRequest(runLabel: runLabel)),
        FactList(facts: <Fact>[askedByFact, changeFact]),
        if (preview != null) CodeBlock(lines: markDiffLines(preview.lines)),
        const DialogNote(
          "Approving saves it as the skill's new version. You can undo it "
          "from the skill's history.",
        ),
      ],
      actions: _buildDecisionButtons(context),
    );
  }

  List<Widget> _buildDecisionButtons(BuildContext context) {
    final NavigatorState navigator = Navigator.of(context);

    return <Widget>[
      AppButton.secondary(
        label: 'Deny',
        onPressed: () => navigator.pop(ApprovalDecision.denied),
      ),
      AppButton.primary(
        label: 'Approve',
        onPressed: () => navigator.pop(ApprovalDecision.approved),
      ),
    ];
  }
}
