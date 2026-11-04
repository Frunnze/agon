import 'package:flutter/services.dart';

import 'package:agent_orchestration/screens/workflow_builder.dart';

MouseCursor chooseCanvasCursor({
  required CanvasHit? agentHit,
  required DiagramEdge? edgeHit,
}) {
  switch (agentHit) {
    case PortHit():
      return SystemMouseCursors.click;
    case NodeHit():
      return SystemMouseCursors.grab;
    case null:
      if (edgeHit == null) {
        return SystemMouseCursors.basic;
      }
      return SystemMouseCursors.click;
  }
}
