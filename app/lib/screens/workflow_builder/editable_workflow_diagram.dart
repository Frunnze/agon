import 'dart:math';
import 'dart:ui';

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
    required this.selectedAgentId,
    required this.deviceNames,
    required this.onAgentSelected,
    required this.onSelectionCleared,
    required this.onAgentMoved,
    required this.onAgentsConnected,
    super.key,
  });

  final Workflow workflow;
  final WorkflowAgentId? selectedAgentId;
  final DeviceNames deviceNames;
  final ValueChanged<WorkflowAgentId> onAgentSelected;
  final VoidCallback onSelectionCleared;
  final AgentMoved onAgentMoved;
  final ValueChanged<AgentConnection> onAgentsConnected;

  @override
  State<EditableWorkflowDiagram> createState() =>
      _EditableWorkflowDiagramState();
}

class _EditableWorkflowDiagramState extends State<EditableWorkflowDiagram> {
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  _CanvasDrag? _drag;

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
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
          look: agent.id == widget.selectedAgentId
              ? NodeLook.selected
              : NodeLook.normal,
        ),
    ];

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context)
          .copyWith(dragDevices: const <PointerDeviceKind>{}),
      child: CanvasScrollArea(
        horizontalController: _horizontalController,
        verticalController: _verticalController,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          dragStartBehavior: DragStartBehavior.down,
          onTapUp: (TapUpDetails details) =>
              _selectAt(agents, details.localPosition),
          onPanStart: (DragStartDetails details) =>
              _startDrag(agents, details.localPosition),
          onPanUpdate: _continueDrag,
          onPanEnd: (DragEndDetails _) => _finishDrag(agents),
          onPanCancel: () => setState(() => _drag = null),
          child: WorkflowDiagram(
            nodes: nodes,
            edges: buildWorkflowEdges(agents, placed.connections),
            drawnEdge: _buildDrawnEdge(agents),
          ),
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

  void _selectAt(List<WorkflowAgent> agents, Offset point) {
    final CanvasHit? hit = findCanvasHit(agents, point);
    if (hit == null) {
      widget.onSelectionCleared();
    } else {
      widget.onAgentSelected(hit.agentId);
    }
  }

  void _startDrag(List<WorkflowAgent> agents, Offset point) {
    final CanvasHit? hit = findCanvasHit(agents, point);

    setState(() {
      switch (hit) {
        case PortHit():
          _drag = _ConnectionDrawing(start: hit, pointer: point);
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

    switch (drag) {
      case _NodeMove():
        setState(() {
          _drag = _NodeMove(
            agentId: drag.agentId,
            position: moveCanvasPosition(drag.position, details.delta),
          );
        });
      case _ConnectionDrawing():
        setState(() {
          _drag = _ConnectionDrawing(
            start: drag.start,
            pointer: details.localPosition,
          );
        });
      case _CanvasPan():
        _scrollBy(_horizontalController, details.delta.dx);
        _scrollBy(_verticalController, details.delta.dy);
      case null:
        break;
    }
  }

  void _scrollBy(ScrollController controller, double delta) {
    if (!controller.hasClients) {
      return;
    }

    final ScrollPosition position = controller.position;
    final double target = min(
      max(position.pixels - delta, position.minScrollExtent),
      position.maxScrollExtent,
    );
    controller.jumpTo(target);
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
