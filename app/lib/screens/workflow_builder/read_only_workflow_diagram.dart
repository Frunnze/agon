import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

class ReadOnlyWorkflowDiagram extends StatefulWidget {
  const ReadOnlyWorkflowDiagram({
    required this.nodes,
    required this.edges,
    super.key,
  });

  final List<DiagramNode> nodes;
  final List<DiagramEdge> edges;

  @override
  State<ReadOnlyWorkflowDiagram> createState() =>
      _ReadOnlyWorkflowDiagramState();
}

class _ReadOnlyWorkflowDiagramState extends State<ReadOnlyWorkflowDiagram> {
  final ValueNotifier<CanvasView> _view = ValueNotifier<CanvasView>(
    startingCanvasView,
  );

  @override
  void dispose() {
    _view.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Rect diagramBounds = findDiagramBounds(
      positions: <CanvasPosition>[
        for (final DiagramNode node in widget.nodes) node.position,
      ],
      edges: widget.edges,
    );

    return GestureDetector(
      dragStartBehavior: DragStartBehavior.down,
      supportedDevices: canvasDragDevices,
      onPanUpdate: _panView,
      child: ZoomableCanvas(
        view: _view,
        diagramBounds: diagramBounds,
        child: WorkflowDiagram(
          size: measureCanvas(diagramBounds),
          nodes: widget.nodes,
          edges: widget.edges,
          drawnEdge: null,
        ),
      ),
    );
  }

  void _panView(DragUpdateDetails details) {
    _view.value = panCanvasView(view: _view.value, delta: details.delta);
  }
}
