import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class LongWordBreakingBox extends SingleChildRenderObjectWidget {
  const LongWordBreakingBox({required Widget super.child, super.key});

  @override
  RenderLongWordBreakingBox createRenderObject(BuildContext context) {
    return RenderLongWordBreakingBox();
  }
}

class RenderLongWordBreakingBox extends RenderProxyBox {
  @override
  double computeMinIntrinsicWidth(double height) => 0;
}
