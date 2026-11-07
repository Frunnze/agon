import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../../../support/app_harness.dart';
import 'refusing_library_repositories.dart';

const String _outageRefusal = 'could not reach the app server: down';
const String _taskRunningRefusal = 'the task is running; cancel its run first';
const RuleId _neverPushRuleId = RuleId('rule-never-push-to-main');

typedef BuildRefusingDependencies = Future<AppDependencies> Function();

final class RefusedDeletionPage {
  const RefusedDeletionPage({
    required this.pageName,
    required this.route,
    required this.pageButtonLabel,
    required this.confirmationTitle,
    required this.keepLabel,
    required this.deleteLabel,
    required this.refusal,
    required this.buildDependencies,
  });

  final String pageName;
  final AppRoute route;
  final String pageButtonLabel;
  final String confirmationTitle;
  final String keepLabel;
  final String deleteLabel;
  final String refusal;
  final BuildRefusingDependencies buildDependencies;
}

Future<AppDependencies> _buildGallery() async {
  return buildGalleryDependencies();
}

Future<AppDependencies> _buildGalleryWithRunningJob() async {
  final AppDependencies dependencies = buildGalleryDependencies();
  await dependencies.taskRepository.startTask(GalleryTaskIds.nightlyTests);
  return dependencies;
}

Future<AppDependencies> _buildGalleryWithSecondReleaseRun() async {
  final AppDependencies dependencies = buildGalleryDependencies();
  await dependencies.taskRepository.startTask(GalleryTaskIds.shipRelease23);
  return dependencies;
}

Future<AppDependencies> _buildGalleryRefusingSkillDeletion() async {
  final AppDependencies base = buildGalleryDependencies();
  return replaceRepositories(
    base,
    skillRepository: DeleteRefusingSkillRepository(
      stored: base.skillRepository,
      refusal: _outageRefusal,
    ),
  );
}

Future<AppDependencies> _buildGalleryRefusingRuleDeletion() async {
  final AppDependencies base = buildGalleryDependencies();
  return replaceRepositories(
    base,
    ruleRepository: DeleteRefusingRuleRepository(
      stored: base.ruleRepository,
      refusal: _outageRefusal,
    ),
  );
}

const List<RefusedDeletionPage> refusedDeletionPages = <RefusedDeletionPage>[
  RefusedDeletionPage(
    pageName: 'project_screen',
    route: ProjectRoute(GalleryProjectIds.acmeApp),
    pageButtonLabel: 'Delete',
    confirmationTitle: 'Delete acme-app?',
    keepLabel: 'Keep project',
    deleteLabel: 'Delete project',
    refusal: 'a task in project acme-app is running; cancel its run first',
    buildDependencies: _buildGallery,
  ),
  RefusedDeletionPage(
    pageName: 'workspace_settings_screen',
    route: SectionRoute(AppSection.settings),
    pageButtonLabel: 'Delete workspace',
    confirmationTitle: 'Delete acme?',
    keepLabel: 'Keep workspace',
    deleteLabel: 'Delete workspace',
    refusal: 'a task in workspace acme is running; cancel its run first',
    buildDependencies: _buildGallery,
  ),
  RefusedDeletionPage(
    pageName: 'workflow_detail_screen',
    route: WorkflowDetailRoute(GalleryWorkflowIds.release),
    pageButtonLabel: 'Delete',
    confirmationTitle: 'Delete release?',
    keepLabel: 'Keep workflow',
    deleteLabel: 'Delete workflow',
    refusal: 'workflow release is still used by a task or job',
    buildDependencies: _buildGallery,
  ),
  RefusedDeletionPage(
    pageName: 'task_form_screen',
    route: EditTaskRoute(GalleryTaskIds.shipRelease24),
    pageButtonLabel: 'Delete',
    confirmationTitle: 'Delete "Ship release 2.4"?',
    keepLabel: 'Keep task',
    deleteLabel: 'Delete task',
    refusal: _taskRunningRefusal,
    buildDependencies: _buildGallery,
  ),
  RefusedDeletionPage(
    pageName: 'job_form_screen',
    route: EditJobRoute(GalleryTaskIds.nightlyTests),
    pageButtonLabel: 'Delete',
    confirmationTitle: 'Delete "Nightly tests"?',
    keepLabel: 'Keep job',
    deleteLabel: 'Delete job',
    refusal: 'the job is running; cancel its run first',
    buildDependencies: _buildGalleryWithRunningJob,
  ),
  RefusedDeletionPage(
    pageName: 'run_page_header',
    route: TaskRunRoute(GalleryRunIds.release41),
    pageButtonLabel: 'Delete',
    confirmationTitle: 'Delete "Ship release 2.3"?',
    keepLabel: 'Keep task',
    deleteLabel: 'Delete task',
    refusal: _taskRunningRefusal,
    buildDependencies: _buildGalleryWithSecondReleaseRun,
  ),
  RefusedDeletionPage(
    pageName: 'skill_detail_screen',
    route: SkillDetailRoute(GallerySkillIds.codeReview),
    pageButtonLabel: 'Delete',
    confirmationTitle: 'Delete code-review?',
    keepLabel: 'Keep skill',
    deleteLabel: 'Delete skill',
    refusal: _outageRefusal,
    buildDependencies: _buildGalleryRefusingSkillDeletion,
  ),
  RefusedDeletionPage(
    pageName: 'rule_detail_screen',
    route: RuleDetailRoute(_neverPushRuleId),
    pageButtonLabel: 'Delete',
    confirmationTitle: 'Delete "Never push to main"?',
    keepLabel: 'Keep rule',
    deleteLabel: 'Delete rule',
    refusal: _outageRefusal,
    buildDependencies: _buildGalleryRefusingRuleDeletion,
  ),
];
