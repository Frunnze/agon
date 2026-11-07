import 'dart:math';

import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/diff_line.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../bridge/support/list_copy_properties.dart';
import '../../bridge/support/node_json_primitives.dart';
import '../../bridge/support/random_typed_values.dart';
import '../../support/random_inputs.dart';
import 'support/domain_model_properties.dart';

DiffLine _randomDiffLine(Random random) {
  return DiffLine(
    change: pickOne(random, DiffLineChange.values),
    text: randomHostileText(random),
  );
}

List<DiffLine> _randomDiffLines(Random random) {
  final List<DiffLine> lines = <DiffLine>[];
  final int count = random.nextInt(5);
  for (int i = 0; i < count; i += 1) {
    lines.add(_randomDiffLine(random));
  }
  return lines;
}

SkillChangePreview _randomPreview(Random random) {
  return SkillChangePreview(
    skillName: randomHostileText(random),
    lines: _randomDiffLines(random),
  );
}

void main() {
  testModelConstructorProperties(
    ModelConstructor<PushCommitsAction>(
      testNamePrefix: 'test_push_commits_action_constructor_property',
      seed: 690301,
      randomFieldValues: (Random random) => <Object?>[
        randomHostileText(random),
        randomHostileText(random),
        randomHostileTexts(random),
      ],
      construct: (ModelFieldValues fieldValues) => PushCommitsAction(
        repository: fieldValues[0]! as String,
        branch: fieldValues[1]! as String,
        commits: fieldValues[2]! as List<String>,
      ),
      readFieldValues: (PushCommitsAction action) => <Object?>[
        action.repository,
        action.branch,
        action.commits,
      ],
    ),
  );

  testListCopyProperties(
    ListCopy<PushCommitsAction, String>(
      testNamePrefix: 'test_push_commits_action_constructor_property_commits',
      seed: 690311,
      buildElement: randomHostileText,
      construct: (Random random, List<String> commits) => PushCommitsAction(
        repository: randomHostileText(random),
        branch: randomHostileText(random),
        commits: commits,
      ),
      readList: (PushCommitsAction action) => action.commits,
    ),
  );

  testModelConstructorProperties(
    ModelConstructor<DeployAction>(
      testNamePrefix: 'test_deploy_action_constructor_property',
      seed: 690321,
      randomFieldValues: (Random random) => <Object?>[
        randomHostileText(random),
      ],
      construct: (ModelFieldValues fieldValues) =>
          DeployAction(target: fieldValues[0]! as String),
      readFieldValues: (DeployAction action) => <Object?>[action.target],
    ),
  );

  testModelConstructorProperties(
    ModelConstructor<DeleteBranchOrFilesAction>(
      testNamePrefix:
          'test_delete_branch_or_files_action_constructor_property',
      seed: 690331,
      randomFieldValues: (Random random) => <Object?>[
        randomHostileText(random),
        randomHostileText(random),
      ],
      construct: (ModelFieldValues fieldValues) => DeleteBranchOrFilesAction(
        repository: fieldValues[0]! as String,
        what: fieldValues[1]! as String,
      ),
      readFieldValues: (DeleteBranchOrFilesAction action) => <Object?>[
        action.repository,
        action.what,
      ],
    ),
  );

  testModelConstructorProperties(
    ModelConstructor<SignWorkflowAction>(
      testNamePrefix: 'test_sign_workflow_action_constructor_property',
      seed: 690341,
      randomFieldValues: (Random random) => <Object?>[
        randomWorkflowId(random),
      ],
      construct: (ModelFieldValues fieldValues) =>
          SignWorkflowAction(workflowId: fieldValues[0]! as WorkflowId),
      readFieldValues: (SignWorkflowAction action) => <Object?>[
        action.workflowId,
      ],
    ),
  );

  testModelConstructorProperties(
    ModelConstructor<RunCommandAction>(
      testNamePrefix: 'test_run_command_action_constructor_property',
      seed: 690351,
      randomFieldValues: (Random random) => <Object?>[
        randomHostileText(random),
        randomHostileText(random),
        randomHostileText(random),
      ],
      construct: (ModelFieldValues fieldValues) => RunCommandAction(
        tool: fieldValues[0]! as String,
        summary: fieldValues[1]! as String,
        command: fieldValues[2]! as String,
      ),
      readFieldValues: (RunCommandAction action) => <Object?>[
        action.tool,
        action.summary,
        action.command,
      ],
    ),
  );

  testModelConstructorProperties(
    ModelConstructor<SkillChangePreview>(
      testNamePrefix: 'test_skill_change_preview_constructor_property',
      seed: 690361,
      randomFieldValues: (Random random) => <Object?>[
        randomHostileText(random),
        _randomDiffLines(random),
      ],
      construct: (ModelFieldValues fieldValues) => SkillChangePreview(
        skillName: fieldValues[0]! as String,
        lines: fieldValues[1]! as List<DiffLine>,
      ),
      readFieldValues: (SkillChangePreview preview) => <Object?>[
        preview.skillName,
        preview.lines,
      ],
    ),
  );

  testListCopyProperties(
    ListCopy<SkillChangePreview, DiffLine>(
      testNamePrefix: 'test_skill_change_preview_constructor_property_lines',
      seed: 690371,
      buildElement: _randomDiffLine,
      construct: (Random random, List<DiffLine> lines) => SkillChangePreview(
        skillName: randomHostileText(random),
        lines: lines,
      ),
      readList: (SkillChangePreview preview) => preview.lines,
    ),
  );

  testModelConstructorProperties(
    ModelConstructor<ImproveSkillAction>(
      testNamePrefix: 'test_improve_skill_action_constructor_property',
      seed: 690381,
      randomFieldValues: (Random random) => <Object?>[
        SkillId(randomUuidText(random)),
        randomHostileText(random),
        if (random.nextBool()) null else _randomPreview(random),
      ],
      construct: (ModelFieldValues fieldValues) => ImproveSkillAction(
        skillId: fieldValues[0]! as SkillId,
        summary: fieldValues[1]! as String,
        preview: fieldValues[2] as SkillChangePreview?,
      ),
      readFieldValues: (ImproveSkillAction action) => <Object?>[
        action.skillId,
        action.summary,
        action.preview,
      ],
    ),
  );
}
