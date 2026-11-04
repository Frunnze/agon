import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:agent_orchestration/theme/layout_density.dart';

const int messageFieldMaximumLines = 8;

const List<LogicalKeyboardKey> _sendKeys = <LogicalKeyboardKey>[
  LogicalKeyboardKey.enter,
  LogicalKeyboardKey.numpadEnter,
];

class MessageField extends StatelessWidget {
  const MessageField({
    required this.controller,
    required this.hintText,
    required this.fieldLabel,
    required this.onSend,
    super.key,
    this.focusNode,
  });

  final TextEditingController controller;
  final String hintText;
  final String fieldLabel;
  final VoidCallback? onSend;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final Widget field = Semantics(
      label: fieldLabel,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        minLines: 1,
        maxLines: messageFieldMaximumLines,
        decoration: InputDecoration(hintText: hintText, hintMaxLines: 1),
      ),
    );

    if (LayoutDensity.of(context).isTouch) {
      return field;
    }

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _sendOnEnter,
      child: field,
    );
  }

  KeyEventResult _sendOnEnter(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent || !_sendKeys.contains(event.logicalKey)) {
      return KeyEventResult.ignored;
    }
    if (HardwareKeyboard.instance.isShiftPressed) {
      return KeyEventResult.ignored;
    }

    final bool isComposingText = !controller.value.composing.isCollapsed;
    if (isComposingText) {
      return KeyEventResult.ignored;
    }

    onSend?.call();
    return KeyEventResult.handled;
  }
}
