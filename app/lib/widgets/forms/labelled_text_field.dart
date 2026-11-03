import 'package:flutter/material.dart';

import 'package:agent_orchestration/widgets/forms/form_field_block.dart';

class LabelledTextField extends StatelessWidget {
  const LabelledTextField({
    required this.label,
    required this.controller,
    required this.problem,
    required this.onChanged,
    super.key,
    this.hint,
    this.style,
    this.textAlign = TextAlign.start,
  });

  final String label;
  final TextEditingController controller;
  final String? problem;
  final ValueChanged<String> onChanged;
  final String? hint;
  final TextStyle? style;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return FormFieldBlock(
      label: label,
      hint: hint,
      children: <Widget>[
        TextField(
          controller: controller,
          style: style,
          textAlign: textAlign,
          autocorrect: false,
          decoration: InputDecoration(errorText: problem),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
