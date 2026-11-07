import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/presentation/problem_text.dart';
import 'package:agent_orchestration/screens/shared/delete_confirmation_dialog.dart';
import 'package:agent_orchestration/screens/shared/deletion_prompts.dart';
import 'package:agent_orchestration/screens/shared/deletion_refusal_dialog.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/app_dialog.dart';

typedef RecordDeletion = Future<void> Function();

Future<void> reviewDeletion({
  required BuildContext context,
  required DeletionPrompt prompt,
  required AppNavigation navigation,
  required VoidCallback leavePage,
  required RecordDeletion deleteRecord,
}) async {
  final NavigatorState dialogNavigator = Navigator.of(
    context,
    rootNavigator: true,
  );
  final DeleteChoice? choice = await showAppDialog<DeleteChoice>(
    context: context,
    builder: (BuildContext _) => DeleteConfirmationDialog(
      title: prompt.title,
      explanation: prompt.explanation,
      facts: prompt.facts,
      keepLabel: prompt.keepLabel,
      deleteLabel: prompt.deleteLabel,
    ),
  );
  if (choice != DeleteChoice.delete) {
    return;
  }

  final List<AppRoute> routesOnThePage = navigation.routes;
  leavePage();
  final List<AppRoute> routesAfterLeaving = navigation.routes;
  while (context.mounted) {
    await WidgetsBinding.instance.endOfFrame;
  }

  try {
    await deleteRecord();
  } on Object catch (problem) {
    final String? explanation = describeProblemForPeople(problem);
    if (explanation == null) {
      rethrow;
    }
    if (listEquals(navigation.routes, routesAfterLeaving)) {
      navigation.restoreRoutes(routesOnThePage);
    }
    await _showRefusal(
      dialogNavigator: dialogNavigator,
      prompt: prompt,
      explanation: explanation,
    );
  }
}

Future<void> _showRefusal({
  required NavigatorState dialogNavigator,
  required DeletionPrompt prompt,
  required String explanation,
}) async {
  if (!dialogNavigator.mounted) {
    return;
  }
  await showAppDialog<void>(
    context: dialogNavigator.context,
    builder: (BuildContext _) =>
        DeletionRefusalDialog(prompt: prompt, explanation: explanation),
  );
}
