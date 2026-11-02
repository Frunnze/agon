import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/scope.dart';

final OnlyWorkspaces _inAcme = OnlyWorkspaces(const <WorkspaceId>[
  GalleryWorkspaceIds.acme,
]);

final List<Skill> gallerySkills = List<Skill>.unmodifiable(<Skill>[
  Skill(
    id: GallerySkillIds.iosRelease,
    name: 'ios-release',
    summary: 'Build, sign and upload the iOS app',
    instructions: 'Build the release scheme.\nSign it.\nUpload it.',
    scope: Scope(
      workspaces: _inAcme,
      projects: OnlyProjects(const <ProjectId>[GalleryProjectIds.acmeApp]),
    ),
    usage: SkillUsage.automatic,
    source: SkillSource.created,
  ),
  const Skill(
    id: GallerySkillIds.codeReview,
    name: 'code-review',
    summary: 'Check a change for bugs and risky edits',
    instructions: 'Read the diff.\nList bugs and risky edits.',
    scope: Scope.everywhere(),
    usage: SkillUsage.automatic,
    source: SkillSource.created,
  ),
  Skill(
    id: GallerySkillIds.gitCleanup,
    name: 'git-cleanup',
    summary: 'Find and delete merged branches',
    instructions: 'List merged branches.\nDelete the old ones.',
    scope: Scope(workspaces: _inAcme, projects: const AllProjects()),
    usage: SkillUsage.whenChosen,
    source: SkillSource.created,
  ),
  const Skill(
    id: GallerySkillIds.writeTests,
    name: 'write-tests',
    summary: 'Write failing tests before changing code',
    instructions: 'Write a failing test.\nMake it pass.',
    scope: Scope.everywhere(),
    usage: SkillUsage.whenChosen,
    source: SkillSource.builtIn,
  ),
]);

final List<Rule> galleryRules = List<Rule>.unmodifiable(<Rule>[
  Rule(
    id: const RuleId('rule-never-push-to-main'),
    title: 'Never push to main',
    details: 'Open a pull request instead.',
    scope: const Scope.everywhere(),
    enabled: true,
    addedAt: galleryDaysAgo(40),
  ),
  Rule(
    id: const RuleId('rule-test-before-changing-code'),
    title: 'Test before changing code',
    details: 'Write a failing test first, then make it pass.',
    scope: const Scope.everywhere(),
    enabled: true,
    addedAt: galleryDaysAgo(30),
  ),
  Rule(
    id: const RuleId('rule-follow-app-style-guide'),
    title: 'Follow the app style guide',
    details: 'For any text a customer will read.',
    scope: Scope(
      workspaces: _inAcme,
      projects: OnlyProjects(const <ProjectId>[GalleryProjectIds.acmeApp]),
    ),
    enabled: true,
    addedAt: galleryDaysAgo(20),
  ),
  Rule(
    id: const RuleId('rule-ask-before-adding-dependency'),
    title: 'Ask before adding a dependency',
    details: 'Explain why it is needed.',
    scope: Scope(workspaces: _inAcme, projects: const AllProjects()),
    enabled: false,
    addedAt: galleryDaysAgo(10),
  ),
]);
