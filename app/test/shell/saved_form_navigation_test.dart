import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../support/random_inputs.dart';

const List<AppRoute> _newPages = <AppRoute>[
  NewTaskRoute(),
  NewJobRoute(),
  NewProjectRoute(),
  NewSkillRoute(),
  NewRuleRoute(presetProjectId: null),
  NewWorkflowTaskRoute(GalleryWorkflowIds.featurePipeline),
  NewWorkflowRoute(),
];

List<AppRoute> _listPagesBelowForms(Random random) {
  return <AppRoute>[
    ProjectRoute(ProjectId('project-${random.nextInt(3)}')),
    SkillDetailRoute(SkillId('skill-${random.nextInt(3)}')),
    const WorkspaceSwitcherRoute(),
    const TaskRunRoute(GalleryRunIds.release42),
  ];
}

List<AppRoute> _buildStackBelowForm(Random random) {
  final List<AppRoute> stack = <AppRoute>[
    SectionRoute(pickOne(random, AppSection.values)),
  ];
  final int depth = random.nextInt(3);
  for (int i = 0; i < depth; i += 1) {
    stack.add(pickOne(random, _listPagesBelowForms(random)));
  }
  return stack;
}

AppNavigation _openFormAbove({
  required List<AppRoute> stackBelow,
  required AppRoute? newPage,
  required Random random,
}) {
  final AppNavigation navigation = AppNavigation(
    initialRoute: stackBelow.first,
  );
  for (final AppRoute route in stackBelow.skip(1)) {
    navigation.openRoute(route);
  }
  if (newPage != null) {
    navigation.openRoute(newPage);
  }
  navigation.openRoute(NewItemFormRoute(pickOne(random, DraftKind.values)));
  return navigation;
}

void main() {
  test('test_close_saved_form_property_lands_below_the_new_page', () {
    final Random random = seededRandom(3201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<AppRoute> stackBelow = _buildStackBelowForm(random);
      final AppRoute? newPage = random.nextBool()
          ? pickOne(random, _newPages)
          : null;
      final AppNavigation navigation = _openFormAbove(
        stackBelow: stackBelow,
        newPage: newPage,
        random: random,
      );

      navigation.closeSavedForm();

      expect(navigation.routes, stackBelow, reason: '$newPage');
    }
  });

  test('test_replace_saved_form_property_shows_only_the_destination', () {
    final Random random = seededRandom(3202);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<AppRoute> stackBelow = _buildStackBelowForm(random);
      final AppRoute? newPage = random.nextBool()
          ? pickOne(random, _newPages)
          : null;
      final AppRoute destination = pickOne(
        random,
        _listPagesBelowForms(random),
      );
      final AppNavigation navigation = _openFormAbove(
        stackBelow: stackBelow,
        newPage: newPage,
        random: random,
      );

      navigation.replaceSavedForm(destination);

      expect(navigation.routes, <AppRoute>[
        ...stackBelow,
        destination,
      ], reason: '$newPage');
    }
  });
}
