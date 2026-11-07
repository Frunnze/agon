import 'dart:math';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_chat.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_runs.dart';
import 'package:agent_orchestration/data/gallery/gallery_tasks.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/audit.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';

import 'app_harness.dart';
import 'fake_task_work_links.dart';

List<Listed> pickRandomRecords<Listed>(Random random, List<Listed> records) {
  final List<Listed> picked = <Listed>[];
  final bool isEmptyPick = random.nextBool();
  if (isEmptyPick) {
    return picked;
  }

  for (final Listed record in records) {
    if (random.nextBool()) {
      picked.add(record);
    }
  }
  return picked;
}

AppDependencies buildDependenciesWithApprovals(
  List<ApprovalRequest> approvals,
) {
  final AppDependencies base = buildGalleryDependencies();

  return replaceRepositories(
    base,
    approvalRepository: FakeApprovalRepository(
      approvals: approvals,
      clock: base.clock,
      currentDeviceId: GalleryDeviceIds.airLaptop,
    ),
  );
}

AppDependencies buildDependenciesWithJobs(List<Task> jobs) {
  final AppDependencies base = buildGalleryDependencies();
  final FakeTaskRepository taskRepository = FakeTaskRepository(
    tasks: <Task>[...galleryTasks, ...jobs],
    runs: galleryRuns,
    clock: base.clock,
    currentDeviceId: GalleryDeviceIds.airLaptop,
    workflowRepository: base.workflowRepository as FakeWorkflowRepository,
  );

  return replaceRepositories(
    base,
    taskRepository: taskRepository,
    jobRepository: FakeJobRepository(
      taskRepository: taskRepository,
      clock: base.clock,
    ),
  );
}

AppDependencies buildDependenciesWithSkills(List<Skill> skills) {
  final AppDependencies base = buildGalleryDependencies();

  return replaceRepositories(
    base,
    skillRepository: FakeSkillRepository(
      skills: skills,
      clock: base.clock,
      workspaceRepository: base.workspaceRepository,
    ),
  );
}

AppDependencies buildDependenciesWithRules(List<Rule> rules) {
  final AppDependencies base = buildGalleryDependencies();

  return replaceRepositories(
    base,
    ruleRepository: FakeRuleRepository(
      rules: rules,
      clock: base.clock,
      workspaceRepository: base.workspaceRepository,
    ),
  );
}

AppDependencies buildDependenciesWithProjects(List<Project> projects) {
  final AppDependencies base = buildGalleryDependencies();

  return replaceRepositories(
    base,
    projectRepository: buildProjectRepositoryOver(base, projects),
  );
}

AppDependencies buildDependenciesWithRepositories({
  required ProjectId projectId,
  required List<Repository> repositories,
}) {
  final List<Project> projects = <Project>[];
  for (final Project project in galleryProjects) {
    if (project.id == projectId) {
      projects.add(project.withRepositories(repositories));
    } else {
      projects.add(project);
    }
  }

  return buildDependenciesWithProjects(projects);
}

AppDependencies buildDependenciesWithWorkflows(List<Workflow> workflows) {
  final AppDependencies base = buildGalleryDependencies();

  return replaceRepositories(
    base,
    workflowRepository: FakeWorkflowRepository(
      workflows: workflows,
      changes: galleryWorkflowChanges,
      clock: base.clock,
      currentDeviceId: GalleryDeviceIds.airLaptop,
      draftTemplate: galleryWorkflows.first,
      drafterDeviceId: GalleryDeviceIds.officeServer,
      draftStepDelay: Duration.zero,
      workspaceRepository: base.workspaceRepository,
    ),
  );
}

AppDependencies buildDependenciesWithRunners(List<Runner> runners) {
  return replaceRepositories(
    buildGalleryDependencies(),
    runnerRepository: FakeRunnerRepository(
      runners: runners,
      thisDeviceOffers: null,
      thisRunnerProblem: null,
    ),
  );
}

AppDependencies buildDependenciesWithAuditEntries(List<AuditEntry> entries) {
  return replaceRepositories(
    buildGalleryDependencies(),
    auditRepository: FakeAuditRepository(entries: entries),
  );
}

AppDependencies buildDependenciesWithChatMessages(List<ChatMessage> messages) {
  return buildDependenciesWithConversation(
    galleryConversationAwaitingApproval.withMessages(messages),
  );
}
