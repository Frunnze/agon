import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/approval_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/approval_views.dart' as node;
import 'package:agent_orchestration/bridge/codecs/workflow_views.dart' as node;
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/diff_line.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import 'support/domain_model_properties.dart';

const node.ImproveSkill _skillImprovement = node.ImproveSkill(
  skillId: SkillId('skill'),
  summary: 'summary',
  proposedInstructions: 'instructions',
);

DiffLineChange _mapChangeThroughApproval(node.DiffLineChange change) {
  final node.SkillChangeView skillChange = node.SkillChangeView(
    skillName: 'skill',
    changes: <node.DiffLine>[node.DiffLine(change: change, text: 'line')],
  );
  final ApprovalAction action = mapApprovalActionFromNode(
    _skillImprovement,
    skillChange: skillChange,
  );
  final ImproveSkillAction improvement = action as ImproveSkillAction;
  return improvement.preview!.lines.single.change;
}

void main() {
  testModelConstructorProperties(
    ModelConstructor<DiffLine>(
      testNamePrefix: 'test_diff_line_constructor_property',
      seed: 690701,
      randomFieldValues: (Random random) => <Object?>[
        pickOne(random, DiffLineChange.values),
        randomHostileText(random),
      ],
      construct: (ModelFieldValues fieldValues) => DiffLine(
        change: fieldValues[0]! as DiffLineChange,
        text: fieldValues[1]! as String,
      ),
      readFieldValues: (DiffLine line) => <Object?>[line.change, line.text],
    ),
  );

  testNodeEnumMappingProperties(
    const NodeEnumMapping<DiffLineChange, node.DiffLineChange>(
      testNamePrefix: 'test_diff_line_change_values_property',
      choices: DiffLineChange.values,
      nodeChoices: node.DiffLineChange.values,
      mapFromNode: _mapChangeThroughApproval,
    ),
  );
}
