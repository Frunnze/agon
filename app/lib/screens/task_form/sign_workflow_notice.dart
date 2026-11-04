import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/screens/task_form/workflow_to_sign.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/notice_banner.dart';

const String _signedOnlyExplanation =
    'Runners only run versions signed with one of your keys, so this task '
    'is not saved or started until then.';

class SignWorkflowNotice extends StatelessWidget {
  const SignWorkflowNotice({
    required this.workflow,
    required this.onOpened,
    super.key,
  });

  final WorkflowToSign workflow;
  final VoidCallback onOpened;

  @override
  Widget build(BuildContext context) {
    return NoticeBanner(
      tone: BannerTone.attention,
      icon: AppIconKind.alert,
      title: 'Sign ${workflow.name} first',
      body: const <Widget>[Text(_signedOnlyExplanation)],
      actions: <Widget>[
        AppButton.secondary(
          label: 'Open ${workflow.name}',
          onPressed: onOpened,
        ),
      ],
    );
  }
}
