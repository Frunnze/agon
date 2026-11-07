import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/screens/shared/deletion_prompts.dart';
import 'package:agent_orchestration/screens/task_form/submit_refusal.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/app_dialog.dart';

class DeletionRefusalDialog extends StatelessWidget {
  const DeletionRefusalDialog({
    required this.prompt,
    required this.explanation,
    super.key,
  });

  final DeletionPrompt prompt;
  final String explanation;

  @override
  Widget build(BuildContext context) {
    final NavigatorState navigator = Navigator.of(context);
    final SubmitRefusal refusal = SubmitRefusal(
      actionLabel: prompt.deleteLabel,
      explanation: explanation,
    );

    return AppDialog(
      title: prompt.title,
      content: <Widget>[SubmitRefusalBanner(refusal: refusal)],
      actions: <Widget>[
        AppButton.secondary(label: prompt.keepLabel, onPressed: navigator.pop),
      ],
    );
  }
}
