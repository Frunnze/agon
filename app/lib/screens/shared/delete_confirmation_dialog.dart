import 'package:flutter/material.dart';

import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/app_dialog.dart';
import 'package:agent_orchestration/widgets/fact_list.dart';

enum DeleteChoice { keep, delete }

class DeleteConfirmationDialog extends StatelessWidget {
  const DeleteConfirmationDialog({
    required this.title,
    required this.explanation,
    required this.facts,
    required this.keepLabel,
    required this.deleteLabel,
    super.key,
  });

  final String title;
  final String explanation;
  final List<Fact> facts;
  final String keepLabel;
  final String deleteLabel;

  @override
  Widget build(BuildContext context) {
    final NavigatorState navigator = Navigator.of(context);

    return AppDialog(
      title: title,
      content: <Widget>[
        Text(explanation),
        if (facts.isNotEmpty) FactList(facts: facts),
        const DialogNote("This can't be undone."),
      ],
      actions: <Widget>[
        AppButton.secondary(
          label: keepLabel,
          onPressed: () => navigator.pop(DeleteChoice.keep),
        ),
        AppButton.danger(
          label: deleteLabel,
          onPressed: () => navigator.pop(DeleteChoice.delete),
        ),
      ],
    );
  }
}
