import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes/gallery_dependencies.dart';
import 'package:agent_orchestration/data/gallery/gallery_item_drafts.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/screens/new_items/library_draft_reviews.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/fact_list.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

import '../../support/random_inputs.dart';

const String _improvementTerm = 'Agents may improve it';

SkillDraftReview _buildReview(AppDependencies dependencies) {
  return SkillDraftReview(
    skillRepository: dependencies.skillRepository,
    workspaceRepository: dependencies.workspaceRepository,
    projectRepository: dependencies.projectRepository,
    navigation: AppNavigation(
      initialRoute: const SectionRoute(AppSection.skills),
    ),
  );
}

DraftedSkill _draftSkill(String name, SkillImprovement improvement) {
  return DraftedSkill(
    SkillDraft(
      name: name,
      summary: 'Write release notes',
      instructions: 'List merged pull requests.',
      scope: const Scope.everywhere(),
      usage: SkillUsage.automatic,
      improvement: improvement,
    ),
  );
}

String _readFactText(List<Fact> facts, String term) {
  final Fact fact = facts.firstWhere((Fact fact) => fact.term == term);
  return <String>[
    for (final TextSegment segment in fact.description) segment.text,
  ].join();
}

void main() {
  test('test_describe_facts_property_shows_the_drafted_improvement', () {
    final Random random = seededRandom(9761);
    final SkillDraftReview review = _buildReview(buildGalleryDependencies());

    for (int i = 0; i < propertyIterations; i += 1) {
      final SkillImprovement improvement = pickOne(
        random,
        SkillImprovement.values,
      );

      final List<Fact> facts = review.describeFacts(
        _draftSkill('release-notes', improvement),
      );

      final List<String> terms = <String>[
        for (final Fact fact in facts) fact.term,
      ];
      expect(
        terms.indexOf(_improvementTerm),
        terms.indexOf('When agents use it') + 1,
      );
      expect(_readFactText(facts, _improvementTerm), improvement.label);
    }
  });

  test('test_approve_property_creates_the_skill_with_improvement', () async {
    final Random random = seededRandom(9762);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final SkillImprovement improvement = pickOne(
        random,
        SkillImprovement.values,
      );

      await _buildReview(dependencies)
          .approve(_draftSkill('drafted-$i', improvement));

      final Skill created = dependencies.skillRepository.listSkills().last;
      expect(created.name, 'drafted-$i');
      expect(created.improvement, improvement);
    }
  });

  test('the gallery skill draft may never be improved', () {
    final ItemDraft draft = buildGalleryItemDrafts()[DraftKind.skill]!;
    final DraftedSkill item = draft.item as DraftedSkill;

    expect(item.skill.improvement, SkillImprovement.never);
  });
}
