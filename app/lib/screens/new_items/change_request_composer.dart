import 'package:flutter/material.dart';

import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/forms/message_field.dart';

class ChangeRequestComposer extends StatefulWidget {
  const ChangeRequestComposer({
    required this.example,
    required this.onSend,
    super.key,
  });

  final String example;
  final ValueChanged<String> onSend;

  @override
  State<ChangeRequestComposer> createState() => _ChangeRequestComposerState();
}

class _ChangeRequestComposerState extends State<ChangeRequestComposer> {
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: AppSpacing.space3),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: MessageField(
              controller: _noteController,
              hintText: widget.example,
              fieldLabel: changeFieldLabel,
              onSend: _send,
            ),
          ),
          const SizedBox(width: AppSpacing.space2),
          AppButton.secondary(
            label: sendChangeLabel,
            icon: AppIconKind.send,
            onPressed: _send,
          ),
        ],
      ),
    );
  }

  void _send() {
    final String note = _noteController.text.trim();
    if (note.isEmpty) {
      return;
    }

    _noteController.clear();
    widget.onSend(note);
  }
}
