import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/data/repository/rule_repository.dart';
import 'package:agent_orchestration/data/repository/skill_repository.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/presentation/scope_catalog.dart';
import 'package:agent_orchestration/screens/new_items/draft_review.dart';
import 'package:agent_orchestration/screens/shared/scope_catalog_lookup.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/code_block.dart';
import 'package:agent_orchestration/widgets/fact_list.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

const String _instructionLineBreak = '\n';
const String everywhereChip = 'Everywhere';
const String unknownWorkspaceChip = 'Unknown workspace';
const String unknownProjectChip = 'Unknown project';

String _findWorkspaceName(ScopeCatalog catalog, WorkspaceId workspaceId) {
  for (final Workspace workspace in catalog.workspaces) {
    if (workspace.id == workspaceId) {
      return workspace.name;
    }
  }
  return unknownWorkspaceChip;
}

String _findProjectName(ScopeCatalog catalog, ProjectId projectId) {
  for (final Project project in catalog.projects) {
    if (project.id == projectId) {
      return project.name;
    }
  }
  return unknownProjectChip;
}

List<String> describeDraftScopeChips(Scope scope, ScopeCatalog catalog) {
  final List<String> chips = <String>[];
  final WorkspaceScope workspaces = scope.workspaces;
  if (workspaces is OnlyWorkspaces) {
    for (final WorkspaceId workspaceId in workspaces.workspaces) {
      chips.add(_findWorkspaceName(catalog, workspaceId));
    }
  }
  final ProjectScope projects = scope.projects;
  if (projects is OnlyProjects) {
    for (final ProjectId projectId in projects.projects) {
      chips.add(_findProjectName(catalog, projectId));
    }
  }

  if (chips.isEmpty) {
    return const <String>[everywhereChip];
  }
  return chips;
}

final class SkillDraftReview implements DraftReview {
  const SkillDraftReview({
    required this.skillRepository,
    required this.workspaceRepository,
    required this.projectRepository,
    required this.navigation,
  });

  final SkillRepository skillRepository;
  final WorkspaceRepository workspaceRepository;
  final ProjectRepository projectRepository;
  final AppNavigation navigation;

  @override
  List<Fact> describeFacts(DraftedItem item) {
    final SkillDraft skill = _requireSkill(item);
    final ScopeCatalog catalog = collectScopeCatalog(
      workspaceRepository: workspaceRepository,
      projectRepository: projectRepository,
    );
    final List<String> instructionLines = skill.instructions.split(
      _instructionLineBreak,
    );

    return <Fact>[
      Fact(
        term: 'Name',
        description: <TextSegment>[TextSegment.monospace(skill.name)],
      ),
      describeOptionalTextFact('What it does', skill.summary),
      describeTextFact('When agents use it', skill.usage.label),
      Fact.chips(
        term: 'Applies to',
        chips: describeDraftScopeChips(skill.scope, catalog),
      ),
      Fact.content(
        term: 'Instructions',
        content: CodeBlock(
          lines: <CodeBlockLine>[
            for (final String line in instructionLines) CodeBlockLine(line),
          ],
        ),
      ),
    ];
  }

  @override
  Future<void> approve(DraftedItem item) async {
    final Skill skill = await skillRepository.createSkill(_requireSkill(item));
    navigation.replaceRoute(SkillDetailRoute(skill.id));
  }

  SkillDraft _requireSkill(DraftedItem item) {
    if (item is! DraftedSkill) {
      throw ArgumentError.value(item, 'item', 'Not a skill draft');
    }
    return item.skill;
  }
}

final class RuleDraftReview implements DraftReview {
  const RuleDraftReview({
    required this.ruleRepository,
    required this.workspaceRepository,
    required this.projectRepository,
    required this.navigation,
  });

  final RuleRepository ruleRepository;
  final WorkspaceRepository workspaceRepository;
  final ProjectRepository projectRepository;
  final AppNavigation navigation;

  @override
  List<Fact> describeFacts(DraftedItem item) {
    final RuleDraft rule = _requireRule(item);
    final ScopeCatalog catalog = collectScopeCatalog(
      workspaceRepository: workspaceRepository,
      projectRepository: projectRepository,
    );

    return <Fact>[
      describeTextFact('Rule', rule.title),
      describeOptionalTextFact('Details', rule.details),
      Fact.chips(
        term: 'Applies to',
        chips: describeDraftScopeChips(rule.scope, catalog),
      ),
    ];
  }

  @override
  Future<void> approve(DraftedItem item) async {
    await ruleRepository.createRule(_requireRule(item));
    navigation.closeRoute();
  }

  RuleDraft _requireRule(DraftedItem item) {
    if (item is! DraftedRule) {
      throw ArgumentError.value(item, 'item', 'Not a rule draft');
    }
    return item.rule;
  }
}
