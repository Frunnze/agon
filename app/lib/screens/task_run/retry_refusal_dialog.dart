import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/screens/task_form/submit_refusal.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/app_dialog.dart';

const String retryRunLabel = 'Retry';
const String _closeLabel = 'Close';

class RetryRefusalDialog extends StatelessWidget {
  const RetryRefusalDialog({
    required this.runLabel,
    required this.explanation,
    super.key,
  });

  final String runLabel;
  final String explanation;

  @override
  Widget build(BuildContext context) {
    final NavigatorState navigator = Navigator.of(context);
    final SubmitRefusal refusal = SubmitRefusal(
      actionLabel: retryRunLabel,
      explanation: explanation,
    );

    return AppDialog(
      title: runLabel,
      content: <Widget>[SubmitRefusalBanner(refusal: refusal)],
      actions: <Widget>[
        AppButton.secondary(label: _closeLabel, onPressed: navigator.pop),
      ],
    );
  }
}
