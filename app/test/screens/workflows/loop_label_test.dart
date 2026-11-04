import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_workflow_agents.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/widget_harness.dart';

const String _poemsWorkflow = 'poems';
const String _loopLabel = 'findings · ≤ 2';
const String _stepKindText = 'Claude Code';
const double _columnPitch = 208;
const double _rowPitch = 152;
const double _pixelTolerance = 0.5;
const Size _narrowWindow = Size(640, desktopHeight);

WorkflowAgent _placePoemStep(String name, double column, int row) {
  return buildGalleryAgent(
    workflowName: _poemsWorkflow,
    name: name,
    kind: AgentKind.claudeCode,
    runsOn: onOfficeServer,
    position: CanvasPosition(
      horizontal: column * _columnPitch,
      vertical: row * _rowPitch,
    ),
  );
}

final List<WorkflowAgent> _poemSteps = <WorkflowAgent>[
  _placePoemStep('plan', 1.5, 0),
  _placePoemStep('choose', 1.5, 1),
  _placePoemStep('quick', 0, 2),
  _placePoemStep('build', 2, 2),
  _placePoemStep('check rhyme', 1, 3),
  _placePoemStep('check length', 2, 3),
  _placePoemStep('check tone', 3, 3),
  _placePoemStep('gate', 2, 4),
  _placePoemStep('clean', 1.5, 5),
  _placePoemStep('ship', 1.5, 6),
];

WorkflowAgentId _findStepId(String name) {
  for (final WorkflowAgent step in _poemSteps) {
    if (step.name == name) {
      return step.id;
    }
  }
  throw StateError('The poems pipeline has no step named $name');
}

AgentConnection _connect(String from, String to, {String? condition}) {
  return AgentConnection(
    from: _findStepId(from),
    to: _findStepId(to),
    condition: condition,
    roundLimit: null,
  );
}

final List<AgentConnection> _poemConnections = <AgentConnection>[
  _connect('plan', 'choose'),
  _connect('choose', 'quick', condition: 'quick'),
  _connect('choose', 'build', condition: 'full'),
  _connect('build', 'check rhyme'),
  _connect('build', 'check length'),
  _connect('build', 'check tone'),
  _connect('check rhyme', 'gate'),
  _connect('check length', 'gate'),
  _connect('check tone', 'gate'),
  _connect('gate', 'clean', condition: 'clean'),
  _connect('quick', 'clean'),
  _connect('clean', 'ship'),
  AgentConnection(
    from: _findStepId('gate'),
    to: _findStepId('build'),
    condition: 'findings',
    roundLimit: 2,
  ),
];

DiagramNode _describePoemNode(WorkflowAgent step) {
  return DiagramNode(
    position: step.position,
    kindText: _stepKindText,
    name: step.name,
    targetText: null,
    stepKind: step.stepKind,
    look: NodeLook.normal,
  );
}

Future<void> _pumpPoemsDiagram(WidgetTester tester, Size window) async {
  useViewSize(tester, window);
  final Widget diagram = ReadOnlyWorkflowDiagram(
    nodes: <DiagramNode>[
      for (final WorkflowAgent step in _poemSteps) _describePoemNode(step),
    ],
    edges: describeDiagramEdges(
      agents: _poemSteps,
      connections: _poemConnections,
      selected: null,
      drawnLoop: null,
    ),
  );
  await tester.pumpWidget(wrapInApp(diagram, platform: desktopPlatform));
  await tester.pump();
}

Rect _findLoopLabel(WidgetTester tester) {
  final Finder labelBox = find
      .ancestor(of: find.text(_loopLabel), matching: find.byType(Padding))
      .first;
  return tester.getRect(labelBox);
}

List<Rect> _findStepBoxes(WidgetTester tester) {
  final Finder stepBoxes = find.byType(AgentNodeBox);
  return <Rect>[
    for (int i = 0; i < stepBoxes.evaluate().length; i += 1)
      tester.getRect(stepBoxes.at(i)),
  ];
}

Rect _findCanvasViewport(WidgetTester tester) {
  final Finder viewport = find.descendant(
    of: find.byType(ZoomableCanvas),
    matching: find.byType(ClipRect),
  );
  return tester.getRect(viewport.first);
}

void _expectInside(Rect shown, Rect viewport) {
  final Rect allowed = viewport.inflate(_pixelTolerance);
  expect(allowed.expandToInclude(shown), allowed, reason: '$shown');
}

void main() {
  testWidgets('the poems loop label covers no step', (
    WidgetTester tester,
  ) async {
    await _pumpPoemsDiagram(tester, const Size(desktopWidth, desktopHeight));

    final Rect label = _findLoopLabel(tester);
    final List<Rect> steps = _findStepBoxes(tester);

    expect(steps.length, _poemSteps.length);
    for (final Rect step in steps) {
      expect(label.overlaps(step), isFalse, reason: '$label on $step');
    }
  });

  testWidgets('fit keeps the poems loop label and every step in view', (
    WidgetTester tester,
  ) async {
    await _pumpPoemsDiagram(tester, _narrowWindow);

    await tester.tap(find.text(fitLabel));
    await tester.pump();

    final Rect viewport = _findCanvasViewport(tester);
    _expectInside(_findLoopLabel(tester), viewport);
    for (final Rect step in _findStepBoxes(tester)) {
      _expectInside(step, viewport);
    }
  });
}
