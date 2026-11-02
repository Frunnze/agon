import 'dart:math';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class WordSafeBox extends SingleChildRenderObjectWidget {
  const WordSafeBox({required Widget super.child, super.key});

  @override
  RenderWordSafeBox createRenderObject(BuildContext context) {
    return RenderWordSafeBox();
  }
}

class RenderWordSafeBox extends RenderProxyBox {
  @override
  void performLayout() {
    final RenderBox? content = child;
    if (content == null) {
      size = constraints.smallest;
      return;
    }

    final double longestWord = content.getMinIntrinsicWidth(double.infinity);
    final double contentWidth = max(constraints.maxWidth, longestWord);
    content.layout(
      constraints.copyWith(minWidth: 0, maxWidth: contentWidth),
      parentUsesSize: true,
    );
    size = constraints.constrain(content.size);
  }
}
