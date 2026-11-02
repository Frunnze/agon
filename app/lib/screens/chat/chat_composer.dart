import 'dart:async';

import 'package:flutter/material.dart';

import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

const int _composerMaximumLines = 4;

class ChatComposer extends StatefulWidget {
  const ChatComposer({required this.onSend, super.key});

  final Future<void> Function(String text) onSend;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final TextEditingController _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
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
            child: TextField(
              controller: _messageController,
              minLines: 1,
              maxLines: _composerMaximumLines,
              decoration: const InputDecoration(
                hintText: 'Message the agent',
                semanticCounterText: 'Message to the agent',
              ),
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
    final String text = _messageController.text;
    if (text.trim().isEmpty) {
      return;
    }

    _messageController.clear();
    await widget.onSend(text);
  }
}
