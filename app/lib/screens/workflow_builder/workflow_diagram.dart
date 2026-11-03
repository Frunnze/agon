import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';

const Offset _centeredOnPoint = Offset(-0.5, -0.5);
const double _labelMiddle = 0.5;

final TextStyle _labelStyle = AppTextStyles.caption
    .merge(AppTextStyles.monospace)
    .copyWith(color: AppColors.inkMuted);

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

    final Offset middle = findCurvePoint(edge.curve, _labelMiddle);
    final Color border = edge.look == EdgeLook.selected
        ? AppColors.action
        : AppColors.line;
    return <Widget>[
      Positioned(
        left: middle.dx,
        top: middle.dy,
        child: FractionalTranslation(
          translation: _centeredOnPoint,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.sunken,
                border: Border.all(color: border),
                borderRadius: BorderRadius.circular(AppRadii.control),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space2,
                  vertical: AppSpacing.space1,
                ),
                child: Text(label, style: _labelStyle, maxLines: 1),
              ),
            ),
          ),
        ),
      ),
    ];
  }
}
