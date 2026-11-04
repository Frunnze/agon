import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/forms/form_action.dart';

final class DraftFormCallbacks {
  const DraftFormCallbacks({
    required this.onChanged,
    required this.onApproved,
    required this.onCancelled,
  });

  final ValueChanged<DraftedItem> onChanged;
  final Future<void> Function(DraftedItem item) onApproved;
  final VoidCallback onCancelled;
}

abstract interface class DraftReview {
  Widget buildForm(DraftedItem item, DraftFormCallbacks callbacks);

  Future<void> approve(DraftedItem item);
}

List<FormAction<V>> buildReviewActions<V>({
  required VoidCallback onCancelled,
  required Future<void> Function(V values) onApproved,
}) {
  return <FormAction<V>>[
    LeaveFormAction<V>(label: cancelReviewLabel, onPressed: onCancelled),
    SubmitFormAction<V>(
      label: approveLabel,
      tone: ButtonTone.primary,
      icon: AppIconKind.check,
      onSubmitted: onApproved,
    ),
  ];
}
