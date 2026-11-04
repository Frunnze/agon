import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

typedef AgentMoved = void Function(
  WorkflowAgentId agentId,
  CanvasPosition position,
);

sealed class _CanvasDrag {
  const _CanvasDrag();
}

final class _NodeMove extends _CanvasDrag {
  const _NodeMove({required this.agentId, required this.position});

  final WorkflowAgentId agentId;
  final CanvasPosition position;
}

final class _ConnectionDrawing extends _CanvasDrag {
  const _ConnectionDrawing({required this.start, required this.pointer});

  final PortHit start;
  final Offset pointer;
}

final class _CanvasPan extends _CanvasDrag {
  const _CanvasPan();
}

class EditableWorkflowDiagram extends StatefulWidget {
  const EditableWorkflowDiagram({
    required this.workflow,
    required this.selection,
    required this.deviceNames,
    required this.onAgentSelected,
    required this.onConnectionSelected,
    required this.onSelectionCleared,
    required this.onAgentMoved,
    required this.onAgentsConnected,
    super.key,
  });

  final Workflow workflow;
  final BuilderSelection? selection;
  final DeviceNames deviceNames;
  final ValueChanged<WorkflowAgentId> onAgentSelected;
  final ValueChanged<AgentConnection> onConnectionSelected;
  final VoidCallback onSelectionCleared;
  final AgentMoved onAgentMoved;
  final ValueChanged<AgentConnection> onAgentsConnected;

  @override
  State<EditableWorkflowDiagram> createState() =>
      _EditableWorkflowDiagramState();
}

class _EditableWorkflowDiagramState extends State<EditableWorkflowDiagram> {
  final ValueNotifier<CanvasView> _view = ValueNotifier<CanvasView>(
    startingCanvasView,
  );
  _CanvasDrag? _drag;

  @override
  void dispose() {
    _view.dispose();
    super.dispose();
  }

  List<WorkflowAgent> _placeAgents() {
    final _CanvasDrag? drag = _drag;
    if (drag is! _NodeMove) {
      return widget.workflow.agents;
    }

    return <WorkflowAgent>[
      for (final WorkflowAgent agent in widget.workflow.agents)
        if (agent.id == drag.agentId)
          agent.copyWith(position: drag.position)
        else
          agent,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final List<WorkflowAgent> agents = _placeAgents();
    final Workflow placed = widget.workflow.withGraph(
      agents: agents,
      connections: widget.workflow.connections,
    );
    final List<DiagramNode> nodes = <DiagramNode>[
      for (final WorkflowAgent agent in agents)
        describeAgentNode(
          agent: agent,
          workflow: placed,
          deviceNames: widget.deviceNames,
          look: agent.id == findSelectedStepId(widget.selection)
              ? NodeLook.selected
              : NodeLook.normal,
        ),
    ];
    final List<DiagramEdge> edges = describeDiagramEdges(
      agents: agents,
      connections: placed.connections,
      selected: findSelectedConnection(widget.selection),
      drawnLoop: findDrawnLoop(widget.selection),
    );

    final Rect diagramBounds = findDiagramBounds(
      positions: <CanvasPosition>[
        for (final DiagramNode node in nodes) node.position,
      ],
      edges: edges,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      dragStartBehavior: DragStartBehavior.down,
      supportedDevices: canvasDragDevices,
      onTapUp: (TapUpDetails details) =>
          _selectAt(agents, edges, details.localPosition),
      onPanStart: (DragStartDetails details) =>
          _startDrag(agents, details.localPosition),
      onPanUpdate: _continueDrag,
      onPanEnd: (DragEndDetails _) => _finishDrag(agents),
      onPanCancel: () => setState(() => _drag = null),
      child: ZoomableCanvas(
        view: _view,
        diagramBounds: diagramBounds,
        child: WorkflowDiagram(
          size: measureCanvas(diagramBounds),
          nodes: nodes,
          edges: edges,
          drawnEdge: _buildDrawnEdge(agents),
        ),
      ),
    );
  }

  EdgeCurve? _buildDrawnEdge(List<WorkflowAgent> agents) {
    final _CanvasDrag? drag = _drag;
    if (drag is! _ConnectionDrawing) {
      return null;
    }

    final WorkflowAgent agent = widget.workflow.findAgent(drag.start.agentId);
    final Offset port = drag.start.side == PortSide.output
        ? findOutputPort(agent.position)
        : findInputPort(agent.position);
    return connectPoints(start: port, end: drag.pointer);
  }

  void _selectAt(
    List<WorkflowAgent> agents,
    List<DiagramEdge> edges,
    Offset viewportPoint,
  ) {
    final Offset canvasPoint = _view.value.findCanvasPoint(viewportPoint);
    final CanvasHit? hit = findCanvasHit(agents, canvasPoint);
    if (hit != null) {
      widget.onAgentSelected(hit.agentId);
      return;
    }

    final List<DiagramEdge> savedEdges = <DiagramEdge>[
      for (final DiagramEdge edge in edges)
        if (widget.workflow.connections.contains(edge.connection)) edge,
    ];
    final DiagramEdge? edgeHit = findEdgeHit(savedEdges, canvasPoint);
    if (edgeHit == null) {
      widget.onSelectionCleared();
    } else {
      widget.onConnectionSelected(edgeHit.connection);
    }
  }

  void _startDrag(List<WorkflowAgent> agents, Offset viewportPoint) {
    final Offset canvasPoint = _view.value.findCanvasPoint(viewportPoint);
    final CanvasHit? hit = findCanvasHit(agents, canvasPoint);

    setState(() {
      switch (hit) {
        case PortHit():
          _drag = _ConnectionDrawing(start: hit, pointer: canvasPoint);
        case NodeHit():
          _drag = _NodeMove(
            agentId: hit.agentId,
            position: widget.workflow.findAgent(hit.agentId).position,
          );
        case null:
          _drag = const _CanvasPan();
      }
    });
  }

  void _continueDrag(DragUpdateDetails details) {
    final _CanvasDrag? drag = _drag;
    final CanvasView view = _view.value;

    switch (drag) {
      case _NodeMove():
        final Offset canvasDelta = details.delta / view.scale;
        setState(() {
          _drag = _NodeMove(
            agentId: drag.agentId,
            position: moveCanvasPosition(drag.position, canvasDelta),
          );
        });
      case _ConnectionDrawing():
        setState(() {
          _drag = _ConnectionDrawing(
            start: drag.start,
            pointer: view.findCanvasPoint(details.localPosition),
          );
        });
      case _CanvasPan():
        _view.value = panCanvasView(view: view, delta: details.delta);
      case null:
        break;
    }
  }

  void _finishDrag(List<WorkflowAgent> agents) {
    final _CanvasDrag? drag = _drag;
    setState(() => _drag = null);

    switch (drag) {
      case _NodeMove():
        widget.onAgentMoved(drag.agentId, drag.position);
      case _ConnectionDrawing():
        final AgentConnection? connection = resolveDraggedConnection(
          start: drag.start,
          end: findCanvasHit(agents, drag.pointer),
        );
        if (connection != null) {
          widget.onAgentsConnected(connection);
        }
      case _CanvasPan():
      case null:
        break;
    }
  }
}
