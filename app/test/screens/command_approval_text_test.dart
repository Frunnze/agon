import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_approvals.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/screens/approvals/approval_text.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

import '../support/random_inputs.dart';

const String _commandToolName = 'Bash';
const String _contextSeparator = ' · ';
const List<String> _toolNames = <String>[
  _commandToolName,
  'WebFetch',
  'WebSearch',
  'Read',
  'Edit',
  'Grep',
];

String _joinSegments(List<TextSegment> segments) {
  final StringBuffer text = StringBuffer();
  for (final TextSegment segment in segments) {
    text.write(segment.text);
  }
  return text.toString();
}

RunCommandAction _randomRunCommand(Random random) {
  return RunCommandAction(
    tool: pickOne(random, _toolNames),
    summary: randomWordPhrase(random),
    command: randomText(random),
  );
}

void main() {
  test('test_describe_tool_use_request_property_names_agent_and_tool', () {
    final Random random = seededRandom(6102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String tool = pickOne(random, _toolNames);
      final String? runLabel = random.nextBool() ? 'run #$i' : null;
      final String asker = runLabel == null
          ? 'An agent'
          : 'The agent in $runLabel';

      final String text = describeToolUseRequest(
        runLabel: runLabel,
        tool: tool,
      );

      if (tool == _commandToolName) {
        expect(text, '$asker wants to run a command.');
      } else {
        expect(text, '$asker wants to use $tool.');
      }
    }
  });

  test('test_describe_approval_title_property_command_leads_with_label', () {
    final Random random = seededRandom(6103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RunCommandAction action = _randomRunCommand(random);
      final String title = describeApprovalTitle(action, galleryWorkflows);

      expect(title, action.summary);
    }
  });

  test('test_describe_approval_context_property_command_shown_in_full', () {
    final Random random = seededRandom(6105);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RunCommandAction action = _randomRunCommand(random);
      final String? runLabel = random.nextBool()
          ? 'release #${random.nextInt(500)}'
          : null;

      final List<TextSegment> context = describeApprovalContext(
        action: action,
        runLabel: runLabel,
        change: null,
      );

      expect(context.last.face, TextFace.monospace);
      expect(context.last.text, action.command);
      final String expected = runLabel == null
          ? action.command
          : '$runLabel$_contextSeparator${action.command}';
      expect(_joinSegments(context), expected);
    }
  });

  test('test_gallery_run_command_approval_property_waits_in_a_run', () {
    final ApprovalRequest approval = galleryRunCommandApproval;

    expect(approval.isPending, isTrue);
    expect(approval.runId, isNotNull);
    expect(approval.action, isA<RunCommandAction>());
  });
}
