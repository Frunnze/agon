import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/item_draft_values.dart'
    as node;
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../bridge/support/list_copy_properties.dart';
import '../../bridge/support/random_typed_values.dart';
import '../../screens/new_items/random_drafts.dart';
import '../../support/random_inputs.dart';
import '../../support/sample_scopes.dart';
import 'support/domain_model_properties.dart';

DraftedItem _randomItem(Random random) {
  final DraftKind kind = pickOne(random, DraftKind.values);
  return randomDraftedItem(random, kind, random.nextInt(100));
}

SkillDraft _randomSkillDraft(Random random) {
  return SkillDraft(
    name: randomHostileText(random),
    summary: randomHostileText(random),
    instructions: randomHostileText(random),
    scope: randomScope(random),
    usage: pickOne(random, SkillUsage.values),
    improvement: pickOne(random, SkillImprovement.values),
  );
}

RuleDraft _randomRuleDraft(Random random) {
  return RuleDraft(
    title: randomHostileText(random),
    details: randomHostileText(random),
    scope: randomScope(random),
  );
}

ItemDraft _randomItemDraft(Random random) {
  return ItemDraft(
    item: _randomItem(random),
    problems: randomHostileTexts(random),
  );
}

ItemDraftChange _randomChange(Random random) {
  return ItemDraftChange(
    draft: _randomItem(random),
    note: randomHostileText(random),
  );
}

void main() {
  testModelConstructorProperties(
    ModelConstructor<DraftedSkill>(
      testNamePrefix: 'test_drafted_skill_constructor_property',
      seed: 691001,
      randomFieldValues: (Random random) => <Object?>[
        _randomSkillDraft(random),
      ],
      construct: (ModelFieldValues fieldValues) =>
          DraftedSkill(fieldValues[0]! as SkillDraft),
      readFieldValues: (DraftedSkill drafted) => <Object?>[drafted.skill],
    ),
  );

  testModelConstructorProperties(
    ModelConstructor<DraftedRule>(
      testNamePrefix: 'test_drafted_rule_constructor_property',
      seed: 691011,
      randomFieldValues: (Random random) => <Object?>[
        _randomRuleDraft(random),
      ],
      construct: (ModelFieldValues fieldValues) =>
          DraftedRule(fieldValues[0]! as RuleDraft),
      readFieldValues: (DraftedRule drafted) => <Object?>[drafted.rule],
    ),
  );

  testModelConstructorProperties(
    ModelConstructor<ItemDraft>(
      testNamePrefix: 'test_item_draft_constructor_property',
      seed: 691021,
      randomFieldValues: (Random random) => <Object?>[
        _randomItem(random),
        randomHostileTexts(random),
      ],
      construct: (ModelFieldValues fieldValues) => ItemDraft(
        item: fieldValues[0]! as DraftedItem,
        problems: fieldValues[1]! as List<String>,
      ),
      readFieldValues: (ItemDraft draft) => <Object?>[
        draft.item,
        draft.problems,
      ],
    ),
  );

  testListCopyProperties(
    ListCopy<ItemDraft, String>(
      testNamePrefix: 'test_item_draft_constructor_property_problems',
      seed: 691031,
      buildElement: randomHostileText,
      construct: (Random random, List<String> problems) =>
          ItemDraft(item: _randomItem(random), problems: problems),
      readList: (ItemDraft draft) => draft.problems,
    ),
  );

  testModelConstructorProperties(
    ModelConstructor<ItemDraftChange>(
      testNamePrefix: 'test_item_draft_change_constructor_property',
      seed: 691051,
      randomFieldValues: (Random random) => <Object?>[
        _randomItem(random),
        randomHostileText(random),
      ],
      construct: (ModelFieldValues fieldValues) => ItemDraftChange(
        draft: fieldValues[0]! as DraftedItem,
        note: fieldValues[1]! as String,
      ),
      readFieldValues: (ItemDraftChange change) => <Object?>[
        change.draft,
        change.note,
      ],
    ),
  );

  testModelConstructorProperties(
    ModelConstructor<ItemDraftRequest>(
      testNamePrefix: 'test_item_draft_request_constructor_property',
      seed: 691061,
      randomFieldValues: (Random random) => <Object?>[
        pickOne(random, DraftKind.values),
        randomHostileText(random),
        if (random.nextBool()) null else randomHostileText(random),
        if (random.nextBool()) null else _randomChange(random),
      ],
      construct: (ModelFieldValues fieldValues) => ItemDraftRequest(
        kind: fieldValues[0]! as DraftKind,
        wish: fieldValues[1]! as String,
        startedFrom: fieldValues[2] as String?,
        change: fieldValues[3] as ItemDraftChange?,
      ),
      readFieldValues: (ItemDraftRequest request) => <Object?>[
        request.kind,
        request.wish,
        request.startedFrom,
        request.change,
      ],
    ),
  );

  testModelConstructorProperties(
    ModelConstructor<DraftRunning>(
      testNamePrefix: 'test_draft_running_constructor_property',
      seed: 691071,
      randomFieldValues: (Random random) => <Object?>[
        pickOne(random, AgentKind.values),
        randomDeviceId(random),
      ],
      construct: (ModelFieldValues fieldValues) => DraftRunning(
        drafterKind: fieldValues[0]! as AgentKind,
        drafterDeviceId: fieldValues[1]! as DeviceId,
      ),
      readFieldValues: (DraftRunning running) => <Object?>[
        running.drafterKind,
        running.drafterDeviceId,
      ],
    ),
  );

  testModelConstructorProperties(
    ModelConstructor<DraftFinished>(
      testNamePrefix: 'test_draft_finished_constructor_property',
      seed: 691081,
      randomFieldValues: (Random random) => <Object?>[
        _randomItemDraft(random),
      ],
      construct: (ModelFieldValues fieldValues) =>
          DraftFinished(fieldValues[0]! as ItemDraft),
      readFieldValues: (DraftFinished finished) => <Object?>[finished.draft],
    ),
  );

  testNodeEnumMappingProperties(
    const NodeEnumMapping<node.DraftKind, DraftKind>(
      testNamePrefix: 'test_draft_kind_values_property',
      choices: node.DraftKind.values,
      nodeChoices: DraftKind.values,
      mapFromNode: mapDraftKindToNode,
    ),
  );
}
