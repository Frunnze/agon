import 'package:flutter/widgets.dart';

List<Widget> spaceVertically(List<Widget> children, double gap) {
  final List<Widget> spaced = <Widget>[];

  for (final Widget child in children) {
    if (spaced.isNotEmpty) {
      spaced.add(SizedBox(height: gap));
    }
    spaced.add(child);
  }

  return spaced;
}

List<Widget> spaceHorizontally(List<Widget> children, double gap) {
  final List<Widget> spaced = <Widget>[];

  for (final Widget child in children) {
    if (spaced.isNotEmpty) {
      spaced.add(SizedBox(width: gap));
    }
    spaced.add(child);
  }

  return spaced;
}
