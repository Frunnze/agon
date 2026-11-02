import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_library.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/rules/agents_markdown.dart';
import 'package:agent_orchestration/data/rules/naming.dart';
import 'package:agent_orchestration/data/rules/scope_rules.dart';

import '../../support/random_inputs.dart';
import '../../support/sample_records.dart';
import '../../support/sample_scopes.dart';

Rule randomRule(Random random, int index) {
  return Rule(
    id: RuleId('rule-$index'),
    title: 'Rule $index ${randomWordPhrase(random)}',
    details: randomText(random),
    scope: randomScope(random),
    enabled: random.nextBool(),
    addedAt: galleryNow,
  );
}

void main() {
  test('test_includes_workspace_property_all_or_listed', () {
    final Random random = seededRandom(9101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkspaceScope scope = randomWorkspaceScope(random);
      final WorkspaceId workspaceId = pickOne(random, sampleWorkspaceIds);
      final bool expected =
          scope is AllWorkspaces ||
          (scope as OnlyWorkspaces).workspaces.contains(workspaceId);

      expect(includesWorkspace(scope, workspaceId), expected);
    }
  });

  test('test_includes_project_property_all_or_listed', () {
    final Random random = seededRandom(9102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ProjectScope scope = randomProjectScope(random);
      final ProjectId projectId = pickOne(random, sampleProjectIds);
      final bool expected =
          scope is AllProjects ||
          (scope as OnlyProjects).projects.contains(projectId);

      expect(includesProject(scope, projectId), expected);
    }
  });

  test('test_does_scope_apply_property_needs_workspace_and_project', () {
    final Random random = seededRandom(9103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Scope scope = randomScope(random);
      final WorkspaceId workspaceId = pickOne(random, sampleWorkspaceIds);
      final ProjectId projectId = pickOne(random, sampleProjectIds);

      expect(
        doesScopeApply(
          scope: scope,
          workspaceId: workspaceId,
          projectId: projectId,
        ),
        includesWorkspace(scope.workspaces, workspaceId) &&
            includesProject(scope.projects, projectId),
      );
      expect(
        doesScopeApply(
          scope: const Scope.everywhere(),
          workspaceId: workspaceId,
          projectId: projectId,
        ),
        isTrue,
      );
    }
  });

  test('test_render_agents_markdown_property_only_enabled_rules_in_order', () {
    final Random random = seededRandom(9104);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Rule> rules = <Rule>[
        for (int index = 0; index < random.nextInt(6); index += 1)
          randomRule(random, index),
      ];
      final WorkspaceId workspaceId = pickOne(random, sampleWorkspaceIds);
      final ProjectId projectId = pickOne(random, sampleProjectIds);
      final List<Rule> included = rules.where((Rule rule) {
        return rule.enabled &&
            doesScopeApply(
              scope: rule.scope,
              workspaceId: workspaceId,
              projectId: projectId,
            );
      }).toList();

      final String markdown = renderAgentsMarkdown(
        rules: rules,
        workspaceId: workspaceId,
        projectId: projectId,
      );

      if (included.isEmpty) {
        expect(markdown, isEmpty);
        continue;
      }
      expect(markdown.startsWith('# Rules\n\n'), isTrue);
      expect(markdown.endsWith('\n'), isTrue);
      final List<String> titleLines = markdown
          .split('\n')
          .where((String line) => line.startsWith('- '))
          .toList();
      expect(titleLines.length, included.length);
      for (int index = 0; index < included.length; index += 1) {
        final String ruleNumber = included[index].id.value.substring(
          'rule-'.length,
        );
        expect(titleLines[index], startsWith('- Rule $ruleNumber'));
      }
    }
  });

  test(
    'test_render_agents_markdown_property_every_line_is_title_or_detail',
    () {
      final Random random = seededRandom(9105);

      for (int i = 0; i < propertyIterations; i += 1) {
        final List<Rule> rules = <Rule>[
          for (int index = 0; index < 4; index += 1) randomRule(random, index),
        ];
        final String markdown = renderAgentsMarkdown(
          rules: rules,
          workspaceId: pickOne(random, sampleWorkspaceIds),
          projectId: pickOne(random, sampleProjectIds),
        );
        if (markdown.isEmpty) {
          continue;
        }

        final List<String> body = markdown
            .substring('# Rules\n\n'.length, markdown.length - 1)
            .split('\n');
        for (final String line in body) {
          final bool isTitle = line.startsWith('- ');
          final bool isDetail =
              line.startsWith('  ') && line.trim().isNotEmpty;
          expect(isTitle || isDetail, isTrue, reason: line);
        }
      }
    },
  );

  test('test_render_agents_markdown_fuzz_property_never_throws', () {
    final Random random = seededRandom(9106);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Rule rule = Rule(
        id: const RuleId('rule-fuzz'),
        title: randomText(random),
        details: randomText(random),
        scope: const Scope.everywhere(),
        enabled: true,
        addedAt: galleryNow,
      );

      final String markdown = renderAgentsMarkdown(
        rules: <Rule>[rule],
        workspaceId: GalleryWorkspaceIds.acme,
        projectId: GalleryProjectIds.acmeApp,
      );

      expect(markdown, startsWith('# Rules\n\n- '));
    }
  });

  test('render agents markdown pins the gallery preview for acme-app', () {
    expect(
      renderAgentsMarkdown(
        rules: galleryRules,
        workspaceId: GalleryWorkspaceIds.acme,
        projectId: GalleryProjectIds.acmeApp,
      ),
      '# Rules\n'
      '\n'
      '- Never push to main.\n'
      '  Open a pull request instead.\n'
      '- Test before changing code.\n'
      '  Write a failing test first, then make it pass.\n'
      '- Follow the app style guide.\n'
      '  For any text a customer will read.\n',
    );
  });

  test(
    'render agents markdown keeps a title that already ends a sentence',
    () {
      final Rule rule = Rule(
        id: const RuleId('rule-question'),
        title: '  Ask   first? ',
        details: 'line one\r\n\r\n  line two  ',
        scope: const Scope.everywhere(),
        enabled: true,
        addedAt: galleryNow,
      );

      expect(
        renderAgentsMarkdown(
          rules: <Rule>[rule],
          workspaceId: GalleryWorkspaceIds.acme,
          projectId: GalleryProjectIds.acmeApp,
        ),
        '# Rules\n\n- Ask first?\n  line one\n  line two\n',
      );
    },
  );

  test('test_describe_name_problem_property_accepts_only_slugs', () {
    final Random random = seededRandom(9107);
    final RegExp slug = RegExp(r'^[a-z0-9-]{1,40}$');

    for (int i = 0; i < propertyIterations; i += 1) {
      final String name = random.nextBool()
          ? randomText(random)
          : randomWordPhrase(random).toLowerCase().replaceAll(' ', '-');

      expect(describeNameProblem(name) == null, slug.hasMatch(name));
    }
  });

  test('describe name problem explains each problem', () {
    expect(describeNameProblem(''), 'Give it a name');
    expect(describeNameProblem('a' * 41), 'Use at most 40 characters');
    expect(
      describeNameProblem('Release Notes'),
      'Use lowercase letters, digits and dashes',
    );
    expect(describeNameProblem('release-notes'), isNull);
    expect(describeNameProblem('release-notes\n'), isNotNull);
  });
}
