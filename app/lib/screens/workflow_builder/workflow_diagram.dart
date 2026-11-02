import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

class WorkflowDiagram extends StatelessWidget {
  const WorkflowDiagram({
    required this.nodes,
    required this.edges,
    required this.drawnEdge,
    super.key,
  });

  final List<DiagramNode> nodes;
  final List<EdgeCurve> edges;
  final EdgeCurve? drawnEdge;

  @override
  Widget build(BuildContext context) {
    final Size size = measureCanvas(<CanvasPosition>[
      for (final DiagramNode node in nodes) node.position,
    ]);

    return SizedBox.fromSize(
      size: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned.fill(
            child: CustomPaint(
              painter: DiagramEdgesPainter(edges: edges, drawnEdge: drawnEdge),
            ),
          ),
          for (final DiagramNode node in nodes)
            Positioned(
              left: node.position.horizontal,
              top: node.position.vertical,
              child: AgentNodeBox(
                kindText: node.kindText,
                name: node.name,
                targetText: node.targetText,
                look: node.look,
              ),
            ),
        ],
      ),
    );
  }
}
