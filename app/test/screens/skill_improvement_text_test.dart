import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/diff_line.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/approvals/approval_text.dart';
import 'package:agent_orchestration/screens/workflows/document_lines.dart';
import 'package:agent_orchestration/widgets/code_block.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

import '../support/random_inputs.dart';

const Map<DiffLineChange, LineChange> _shownChanges =
    <DiffLineChange, LineChange>{
      DiffLineChange.unchanged: LineChange.unchanged,
      DiffLineChange.added: LineChange.added,
      DiffLineChange.removed: LineChange.removed,
    };

String _joinSegments(List<TextSegment> segments) {
  final StringBuffer text = StringBuffer();
  for (final TextSegment segment in segments) {
    text.write(segment.text);
  }
  return text.toString();
}

List<DiffLine> _randomDiffLines(Random random) {
  final int count = random.nextInt(6);
  return <DiffLine>[
    for (int i = 0; i < count; i += 1)
      DiffLine(
        change: pickOne(random, DiffLineChange.values),
        text: randomText(random),
      ),
  ];
}

ImproveSkillAction _randomImprovement(Random random) {
  final SkillChangePreview? preview = random.nextBool()
      ? SkillChangePreview(
          skillName: 'skill-${random.nextInt(1000)}',
          lines: _randomDiffLines(random),
        )
      : null;
  return ImproveSkillAction(
    skillId: SkillId('skill-${random.nextInt(1000)}'),
    summary: randomWordPhrase(random),
    preview: preview,
  );
}

void main() {
  test('test_mark_diff_lines_property_keeps_order_change_and_text', () {
    final Random random = seededRandom(6201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<DiffLine> lines = _randomDiffLines(random);

      final List<CodeBlockLine> marked = markDiffLines(lines);

      expect(marked.length, lines.length);
      for (int j = 0; j < lines.length; j += 1) {
        expect(marked[j].change, _shownChanges[lines[j].change]);
        expect(marked[j].text.substring(diffMarkerWidth), lines[j].text);
      }
    }
  });

  test('test_mark_diff_lines_property_matches_document_diff_markers', () {
    final Random random = seededRandom(6202);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String before = 'shared\n${randomWordPhrase(random)}';
      final String after = 'shared\n${randomWordPhrase(random)}\nadded';
      final List<CodeBlockLine> documentLines = diffDocumentLines(
        before,
        after,
      );
      final List<DiffLine> sameLines = <DiffLine>[
        for (final CodeBlockLine line in documentLines)
          DiffLine(
            change: DiffLineChange.values.byName(line.change.name),
            text: line.text.substring(diffMarkerWidth),
          ),
      ];

      final List<CodeBlockLine> marked = markDiffLines(sameLines);

      expect(
        <String>[for (final CodeBlockLine line in marked) line.text],
        <String>[for (final CodeBlockLine line in documentLines) line.text],
      );
    }
  });

  test('test_describe_approval_title_property_names_the_improved_skill', () {
    final Random random = seededRandom(6203);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ImproveSkillAction action = _randomImprovement(random);
      final SkillChangePreview? preview = action.preview;

      final String title = describeApprovalTitle(action, const <Workflow>[]);

      if (preview == null) {
        expect(title, 'Improve a deleted skill');
      } else {
        expect(title, 'Improve skill ${preview.skillName}');
      }
    }
  });

  test('test_describe_approval_context_property_run_then_summary', () {
    final Random random = seededRandom(6204);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ImproveSkillAction action = _randomImprovement(random);
      final String? runLabel = random.nextBool()
          ? 'release #${random.nextInt(500)}'
          : null;

      final String context = _joinSegments(
        describeApprovalContext(
          action: action,
          runLabel: runLabel,
          change: null,
        ),
      );

      if (runLabel == null) {
        expect(context, action.summary);
      } else {
        expect(context, '$runLabel · ${action.summary}');
      }
    }
  });

  test('test_describe_skill_change_request_property_names_the_run', () {
    final Random random = seededRandom(6205);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String runLabel = 'release #${random.nextInt(500)}';

      expect(
        describeSkillChangeRequest(runLabel: runLabel),
        'The agent in $runLabel wants to change these instructions.',
      );
    }
    expect(
      describeSkillChangeRequest(runLabel: null),
      'An agent wants to change these instructions.',
    );
  });
}
