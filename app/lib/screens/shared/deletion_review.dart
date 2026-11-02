import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/screens/shared/delete_confirmation_dialog.dart';
import 'package:agent_orchestration/screens/shared/deletion_prompts.dart';
import 'package:agent_orchestration/widgets/app_dialog.dart';

typedef RecordDeletion = Future<void> Function();

Future<void> reviewDeletion({
  required BuildContext context,
  required DeletionPrompt prompt,
  required VoidCallback leavePage,
  required RecordDeletion deleteRecord,
}) async {
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

  leavePage();
  while (context.mounted) {
    await WidgetsBinding.instance.endOfFrame;
  }
  await deleteRecord();
}
