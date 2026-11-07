import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/approval_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/approval_views.dart' as node;
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/workflow_views.dart' as node;
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/diff_line.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../../bridge/support/hostile_texts.dart';
import '../../../bridge/support/node_wire_names.dart';
import '../../../bridge/support/random_run_json.dart';
import '../../../support/random_inputs.dart';
import '../support/node_enum_mapping_properties.dart';

const String _proposedInstructionsField = 'proposed_instructions';

node.ApprovalAction _decodeRandomAction(Random random) {
  return node.ApprovalAction.fromJson(randomApprovalActionJson(random));
}

node.SkillChangeView? _decodeRandomSkillChange(Random random) {
  if (random.nextBool()) {
    return null;
  }
  return node.SkillChangeView.fromJson(randomSkillChangeViewJson(random));
}

node.ImproveSkill _randomImproveSkill(Random random) {
  return node.ImproveSkill(
    skillId: SkillId(randomHostileText(random)),
    summary: randomHostileText(random),
    proposedInstructions: randomHostileText(random),
  );
}

node.SkillChangeView _randomHostileSkillChange(Random random) {
  final List<node.DiffLine> changes = <node.DiffLine>[
    for (final String text in randomHostileTexts(random))
      node.DiffLine(
        change: pickOne(random, node.DiffLineChange.values),
        text: text,
      ),
  ];
  return node.SkillChangeView(
    skillName: randomHostileText(random),
    changes: changes,
  );
}

SkillChangePreview? _mapPreview(node.SkillChangeView? skillChange) {
  final ApprovalAction action = mapApprovalActionFromNode(
    const node.ImproveSkill(
      skillId: SkillId('skill'),
      summary: '',
      proposedInstructions: '',
    ),
    skillChange: skillChange,
  );
  if (action is! ImproveSkillAction) {
    throw StateError('an improve skill action changed its kind');
  }
  return action.preview;
}

DiffLineChange _mapDiffLineChangeAlone(node.DiffLineChange change) {
  final node.SkillChangeView skillChange = node.SkillChangeView(
    skillName: '',
    changes: <node.DiffLine>[node.DiffLine(change: change, text: '')],
  );
  final SkillChangePreview? preview = _mapPreview(skillChange);
  if (preview == null) {
    throw StateError('a given skill change came back missing');
  }
  return preview.lines.single.change;
}

Map<String, Object?> _describeNodeAction(node.ApprovalAction action) {
  final Map<String, Object?> description = Map<String, Object?>.of(
    decodeObject(action.toJson()),
  );
  description.remove(_proposedInstructionsField);
  return description;
}

Map<String, Object?> _describeModelAction(ApprovalAction action) {
  return switch (action) {
    PushCommitsAction() => <String, Object?>{
      'kind': node.PushCommits.kind,
      'repository': action.repository,
      'branch': action.branch,
      'commits': action.commits,
    },
    DeployAction() => <String, Object?>{
      'kind': node.Deploy.kind,
      'target': action.target,
    },
    DeleteBranchOrFilesAction() => <String, Object?>{
      'kind': node.DeleteBranchOrFiles.kind,
      'repository': action.repository,
      'what': action.what,
    },
    SignWorkflowAction() => <String, Object?>{
      'kind': node.SignWorkflow.kind,
      'workflow_id': action.workflowId.value,
    },
    RunCommandAction() => <String, Object?>{
      'kind': node.RunCommand.kind,
      'tool': action.tool,
      'summary': action.summary,
      'command': action.command,
    },
    ImproveSkillAction() => <String, Object?>{
      'kind': node.ImproveSkill.kind,
      'skill_id': action.skillId.value,
      'summary': action.summary,
    },
  };
}

void main() {
  testEnumMappingFromNodeProperties(
    const EnumMappingFromNode<node.DiffLineChange, DiffLineChange>(
      functionName: 'map_diff_line_from_node',
      seed: 71501,
      rustWireNames: nodeDiffChanges,
      decodeNode: node.DiffLineChange.decode,
      modelValues: DiffLineChange.values,
      mapFromNode: _mapDiffLineChangeAlone,
    ),
  );

  test('test_map_diff_line_from_node_property_keeps_text_in_order', () {
    final Random random = seededRandom(71503);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.SkillChangeView skillChange = _randomHostileSkillChange(
        random,
      );

      final SkillChangePreview? preview = _mapPreview(skillChange);

      expect(preview?.lines.map((DiffLine line) => line.text), <String>[
        for (final node.DiffLine line in skillChange.changes) line.text,
      ]);
    }
  });

  test('test_map_skill_change_preview_from_node_property_'
      'missing_change_gives_no_preview', () {
    final Random random = seededRandom(71504);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.SkillChangeView? skillChange = _decodeRandomSkillChange(
        random,
      );

      final SkillChangePreview? preview = _mapPreview(skillChange);

      expect(preview == null, skillChange == null);
    }
  });

  test('test_map_skill_change_preview_from_node_property_'
      'keeps_the_skill_name_and_every_line', () {
    final Random random = seededRandom(71505);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.SkillChangeView skillChange = _randomHostileSkillChange(
        random,
      );

      final SkillChangePreview? preview = _mapPreview(skillChange);

      expect(preview?.skillName, skillChange.skillName);
      expect(preview?.lines.length, skillChange.changes.length);
      for (int j = 0; j < skillChange.changes.length; j += 1) {
        final node.DiffLine wireLine = skillChange.changes[j];
        expect(preview?.lines[j].change.name, wireLine.change.name);
      }
    }
  });

  test('test_map_skill_change_preview_from_node_property_'
      'lines_cannot_be_changed', () {
    final Random random = seededRandom(71506);
    for (int i = 0; i < propertyIterations; i += 1) {
      final SkillChangePreview? preview = _mapPreview(
        _randomHostileSkillChange(random),
      );
      const DiffLine extraLine = DiffLine(
        change: DiffLineChange.added,
        text: 'extra',
      );

      expect(() => preview?.lines.add(extraLine), throwsUnsupportedError);
    }
  });

  test('test_map_approval_action_from_node_property_keeps_every_field', () {
    final Random random = seededRandom(71507);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.ApprovalAction wire = _decodeRandomAction(random);

      final ApprovalAction action = mapApprovalActionFromNode(
        wire,
        skillChange: _decodeRandomSkillChange(random),
      );

      expect(
        jsonEncode(_describeModelAction(action)),
        jsonEncode(_describeNodeAction(wire)),
      );
    }
  });

  test('test_map_approval_action_from_node_property_'
      'skill_change_only_reaches_improve_skill', () {
    final Random random = seededRandom(71508);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.ApprovalAction wire = _decodeRandomAction(random);
      final node.SkillChangeView skillChange = _randomHostileSkillChange(
        random,
      );

      final ApprovalAction withChange = mapApprovalActionFromNode(
        wire,
        skillChange: skillChange,
      );
      final ApprovalAction withoutChange = mapApprovalActionFromNode(
        wire,
        skillChange: null,
      );

      expect(
        jsonEncode(_describeModelAction(withChange)),
        jsonEncode(_describeModelAction(withoutChange)),
      );
      if (withChange is ImproveSkillAction) {
        expect(withChange.preview?.skillName, skillChange.skillName);
      }
    }
  });

  test('test_map_approval_action_from_node_property_keeps_hostile_texts', () {
    final Random random = seededRandom(71509);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<node.ApprovalAction> wires = <node.ApprovalAction>[
        node.PushCommits(
          repository: randomHostileText(random),
          branch: randomHostileText(random),
          commits: randomHostileTexts(random),
        ),
        node.Deploy(target: randomHostileText(random)),
        node.DeleteBranchOrFiles(
          repository: randomHostileText(random),
          what: randomHostileText(random),
        ),
        node.SignWorkflow(workflowId: WorkflowId(randomHostileText(random))),
        node.RunCommand(
          tool: randomHostileText(random),
          summary: randomHostileText(random),
          command: randomHostileText(random),
        ),
        _randomImproveSkill(random),
      ];
      final node.ApprovalAction wire = pickOne(random, wires);

      final ApprovalAction action = mapApprovalActionFromNode(
        wire,
        skillChange: null,
      );

      expect(
        jsonEncode(_describeModelAction(action)),
        jsonEncode(_describeNodeAction(wire)),
      );
    }
  });
}
