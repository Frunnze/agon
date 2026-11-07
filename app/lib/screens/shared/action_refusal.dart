import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/presentation/problem_text.dart';
import 'package:agent_orchestration/screens/task_form/submit_refusal.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/app_dialog.dart';

typedef PersonAction = Future<void> Function();

enum ActionOutcome { done, refused }

const String changeSettingLabel = 'Change';
const String _closeLabel = 'Close';

Future<SubmitRefusal?> catchRefusal({
  required String actionLabel,
  required PersonAction action,
}) async {
  try {
    await action();
  } on Object catch (problem) {
    final String? explanation = describeProblemForPeople(problem);
    if (explanation == null) {
      rethrow;
    }
    return SubmitRefusal(actionLabel: actionLabel, explanation: explanation);
  }
  return null;
}

Future<ActionOutcome> runShowingRefusal({
  required BuildContext context,
  required String title,
  required String actionLabel,
  required PersonAction action,
}) async {
  final NavigatorState dialogNavigator = Navigator.of(
    context,
    rootNavigator: true,
  );
  final SubmitRefusal? refusal = await catchRefusal(
    actionLabel: actionLabel,
    action: action,
  );
  if (refusal == null) {
    return ActionOutcome.done;
  }

  if (dialogNavigator.mounted) {
    await showAppDialog<void>(
      context: dialogNavigator.context,
      builder: (BuildContext _) =>
          ActionRefusalDialog(title: title, refusal: refusal),
    );
  }
  return ActionOutcome.refused;
}

class ActionRefusalDialog extends StatelessWidget {
  const ActionRefusalDialog({
    required this.title,
    required this.refusal,
    super.key,
  });

  final String title;
  final SubmitRefusal refusal;

  @override
  Widget build(BuildContext context) {
    final NavigatorState navigator = Navigator.of(context);

    return AppDialog(
      title: title,
      content: <Widget>[SubmitRefusalBanner(refusal: refusal)],
      actions: <Widget>[
        AppButton.secondary(label: _closeLabel, onPressed: navigator.pop),
      ],
    );
  }
}
