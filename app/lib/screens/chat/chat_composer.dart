import 'dart:async';

import 'package:flutter/material.dart';

import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/forms/message_field.dart';

class ChatComposer extends StatefulWidget {
  const ChatComposer({required this.onSend, super.key});

  final Future<void> Function(String text) onSend;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _messageFocusNode.requestFocus();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messageFocusNode.dispose();
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
              controller: _messageController,
              focusNode: _messageFocusNode,
              hintText: 'Message the agent',
              fieldLabel: 'Message to the agent',
              onSend: () => unawaited(_send()),
            ),
          ),
          const SizedBox(width: AppSpacing.space2),
          AppButton.primary(
            label: 'Send',
            icon: AppIconKind.send,
            onPressed: () => unawaited(_send()),
          ),
        ],
      ),
    );
  }

  Future<void> _send() async {
    final String message = _messageController.text.trim();
    if (message.isEmpty) {
      return;
    }

    _messageController.clear();
    _messageFocusNode.requestFocus();
    await widget.onSend(message);
  }
}
