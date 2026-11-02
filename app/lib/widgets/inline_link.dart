import 'package:flutter/widgets.dart';

const TextStyle _linkStyle = TextStyle(decoration: TextDecoration.underline);

class InlineLink extends StatelessWidget {
  const InlineLink({required this.label, required this.onPressed, super.key});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      link: true,
      button: true,
      child: GestureDetector(
        onTap: onPressed,
        child: Text(label, style: _linkStyle),
      ),
    );
  }
}
