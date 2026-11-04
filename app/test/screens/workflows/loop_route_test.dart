import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/random_inputs.dart';

const double _columnPitch = 208;
const double _rowPitch = 152;
const int _largestRowCount = 7;
const int _columnCount = 5;
const double _largestLabelWidth = 240;
const double _largestLabelHeight = 30;
const double _sampleStep = 2;
const double _edgeTolerance = 0.5;
const double _roundingTolerance = 1e-9;

final class _LoopCase {
  const _LoopCase({
    required this.source,
    required this.target,
    required this.nodes,
    required this.labelSize,
  });

  final Rect source;
  final Rect target;
  final List<Rect> nodes;
  final Size labelSize;
}

List<List<Rect>> _randomLayeredRows(Random random) {
  final int rowCount = 2 + random.nextInt(_largestRowCount - 1);
  final List<List<Rect>> rows = <List<Rect>>[];

  for (int row = 0; row < rowCount; row += 1) {
    final List<int> columns = List<int>.generate(_columnCount, (int i) => i);
    columns.shuffle(random);
    final int stepCount = 1 + random.nextInt(_columnCount);
    final List<Rect> steps = <Rect>[];
    for (final int column in columns.take(stepCount)) {
      steps.add(
        Rect.fromLTWH(
          column * _columnPitch,
          row * _rowPitch,
          CanvasMetrics.nodeWidth,
          CanvasMetrics.nodeHeight,
        ),
      );
    }
    rows.add(steps);
  }

  return rows;
}

_LoopCase _randomLoopCase(Random random) {
  final List<List<Rect>> rows = _randomLayeredRows(random);
  final int sourceRow = random.nextInt(rows.length);
  int targetRow = random.nextInt(rows.length - 1);
  if (targetRow >= sourceRow) {
    targetRow += 1;
  }

  final List<Rect> nodes = <Rect>[
    for (final List<Rect> row in rows) ...row,
  ];
  nodes.shuffle(random);
  final Size labelSize = Size(
    random.nextDouble() * _largestLabelWidth,
    random.nextDouble() * _largestLabelHeight,
  );

  return _LoopCase(
    source: pickOne(random, rows[sourceRow]),
    target: pickOne(random, rows[targetRow]),
    nodes: nodes,
    labelSize: labelSize,
  );
}

LoopRoute _route(_LoopCase loopCase) {
  return routeLoopEdge(
    source: loopCase.source,
    target: loopCase.target,
    nodes: loopCase.nodes,
    labelSize: loopCase.labelSize,
  );
}

List<Offset> _samplePath(List<Offset> corners) {
  final List<Offset> samples = <Offset>[];

  for (int i = 1; i < corners.length; i += 1) {
    final Offset segmentStart = corners[i - 1];
    final Offset segmentEnd = corners[i];
    final double length = (segmentEnd - segmentStart).distance;
    final int stepCount = max(1, (length / _sampleStep).ceil());
    for (int step = 0; step <= stepCount; step += 1) {
      final double progress = step / stepCount;
      samples.add(Offset.lerp(segmentStart, segmentEnd, progress)!);
    }
  }

  return samples;
}

void main() {
  test('test_route_loop_edge_property_path_never_crosses_a_step', () {
    final Random random = seededRandom(9901);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _LoopCase loopCase = _randomLoopCase(random);
      final LoopRoute route = _route(loopCase);

      for (final Offset point in _samplePath(route.corners)) {
        for (final Rect node in loopCase.nodes) {
          final Rect inside = node.deflate(_edgeTolerance);
          expect(inside.contains(point), isFalse, reason: '$point in $node');
        }
      }
    }
  });

  test('test_route_loop_edge_property_label_never_covers_a_step', () {
    final Random random = seededRandom(9902);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _LoopCase loopCase = _randomLoopCase(random);
      final LoopRoute route = _route(loopCase);
      final Rect label = route.labelArea;

      final Size labelSize = loopCase.labelSize;
      expect(label.width, closeTo(labelSize.width, _roundingTolerance));
      expect(label.height, closeTo(labelSize.height, _roundingTolerance));
      for (final Rect node in loopCase.nodes) {
        expect(label.overlaps(node), isFalse, reason: '$label on $node');
      }
    }
  });

  test('test_route_loop_edge_property_label_sits_on_the_outer_part', () {
    final Random random = seededRandom(9903);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _LoopCase loopCase = _randomLoopCase(random);
      final LoopRoute route = _route(loopCase);
      final Offset labelCentre = route.labelArea.center;
      final List<Offset> outerEnds = <Offset>[
        for (final Offset corner in route.corners)
          if ((corner.dx - labelCentre.dx).abs() < _roundingTolerance)
            corner,
      ];

      expect(outerEnds.length, 2);
      final double middle = (outerEnds.first.dy + outerEnds.last.dy) / 2;
      expect(labelCentre.dy, closeTo(middle, _roundingTolerance));
      for (final Offset corner in route.corners) {
        final double outerReach = labelCentre.dx + _roundingTolerance;
        expect(corner.dx, lessThanOrEqualTo(outerReach));
      }
    }
  });

  test('test_route_loop_edge_property_runs_from_side_to_side', () {
    final Random random = seededRandom(9904);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _LoopCase loopCase = _randomLoopCase(random);
      final LoopRoute route = _route(loopCase);
      final Offset start = route.corners.first;
      final Offset end = route.corners.last;

      expect(start, loopCase.source.centerRight);
      expect(end.dy, loopCase.target.center.dy);
      expect(end.dx, greaterThanOrEqualTo(loopCase.target.right));
      expect(
        end.dx,
        lessThanOrEqualTo(loopCase.target.right + CanvasMetrics.arrowGap),
      );
    }
  });

  test('test_route_loop_edge_property_turns_only_at_right_angles', () {
    final Random random = seededRandom(9905);

    for (int i = 0; i < propertyIterations; i += 1) {
      final LoopRoute route = _route(_randomLoopCase(random));

      for (int corner = 1; corner < route.corners.length; corner += 1) {
        final Offset step = route.corners[corner] - route.corners[corner - 1];
        expect(step.dx == 0 || step.dy == 0, isTrue, reason: '$step');
      }
    }
  });

  test('test_route_loop_edge_property_same_layout_same_route', () {
    final Random random = seededRandom(9906);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _LoopCase loopCase = _randomLoopCase(random);
      final List<Rect> reordered = List<Rect>.of(loopCase.nodes);
      reordered.shuffle(random);

      final LoopRoute first = _route(loopCase);
      final LoopRoute again = routeLoopEdge(
        source: loopCase.source,
        target: loopCase.target,
        nodes: reordered,
        labelSize: loopCase.labelSize,
      );

      expect(again.corners, first.corners);
      expect(again.labelArea, first.labelArea);
    }
  });
}
