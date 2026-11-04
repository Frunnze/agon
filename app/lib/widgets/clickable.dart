import 'package:flutter/widgets.dart';

class Clickable extends StatelessWidget {
  const Clickable({required this.onTap, required this.child, super.key});

  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final MouseCursor cursor = onTap == null
        ? SystemMouseCursors.basic
        : SystemMouseCursors.click;

    return MouseRegion(
      cursor: cursor,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: child,
      ),
    );
  }
}
