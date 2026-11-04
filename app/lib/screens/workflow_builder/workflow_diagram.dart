import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/screens/workflow_builder.dart';

const Offset _centeredOnPoint = Offset(-0.5, -0.5);

class WorkflowDiagram extends StatelessWidget {
  const WorkflowDiagram({
    required this.size,
    required this.nodes,
    required this.edges,
    required this.drawnEdge,
    super.key,
  });

  final Size size;
  final List<DiagramNode> nodes;
  final List<DiagramEdge> edges;
  final EdgeCurve? drawnEdge;

  @override
  Widget build(BuildContext context) {
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
                stepKind: node.stepKind,
                look: node.look,
              ),
            ),
          for (final DiagramEdge edge in edges) ..._buildLabel(edge),
        ],
      ),
    );
  }

  List<Widget> _buildLabel(DiagramEdge edge) {
    final String? label = edge.label;
    if (label == null) {
      return const <Widget>[];
    }

    final Offset centre = findLabelCentre(edge.route);
    return <Widget>[
      Positioned(
        left: centre.dx,
        top: centre.dy,
        child: FractionalTranslation(
          translation: _centeredOnPoint,
          child: IgnorePointer(
            child: EdgeLabelBox(label: label, look: edge.look),
          ),
        ),
      ),
    ];
  }
}
