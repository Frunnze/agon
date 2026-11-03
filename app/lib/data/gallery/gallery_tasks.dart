import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';

Task _buildGalleryTask({
  required TaskId id,
  required String title,
  required ProjectId projectId,
  required TaskDoer doer,
  required TaskStatus status,
  required DateTime createdAt,
  String details = '',
  List<SkillId> skills = const <SkillId>[],
  Schedule? schedule,
}) {
  return Task(
    id: id,
    title: title,
    details: details,
    projectId: projectId,
    doer: doer,
    runsOn: const AnyFreeRunner(),
    agentPlace: AgentPlace.container,
    skills: skills,
    usesAutomaticSkills: true,
    approvalPolicy: ApprovalPolicy.askBeforeRiskyActions,
    schedule: schedule,
    status: status,
    createdAt: createdAt,
  );
}

final List<Task> galleryTasks = List<Task>.unmodifiable(<Task>[
  _buildGalleryTask(
    id: GalleryTaskIds.shipRelease24,
    title: 'Ship release 2.4',
    projectId: GalleryProjectIds.acmeApp,
    doer: const WorkflowDoer(GalleryWorkflowIds.release),
    status: TaskStatus.running,
    createdAt: galleryToday(14, 1),
  ),
  _buildGalleryTask(
    id: GalleryTaskIds.cleanUpBranches,
    title: 'Clean up old feature branches',
    details:
        'Delete remote branches merged over 30 days ago.\n'
        'Keep release branches.',
    projectId: GalleryProjectIds.acmeApp,
    doer: const OneAgentDoer(AgentKind.claudeCode),
    skills: const <SkillId>[GallerySkillIds.gitCleanup],
    status: TaskStatus.toDo,
    createdAt: galleryToday(13, 40),
  ),
  _buildGalleryTask(
    id: GalleryTaskIds.shipRelease23,
    title: 'Ship release 2.3',
    projectId: GalleryProjectIds.acmeApp,
    doer: const WorkflowDoer(GalleryWorkflowIds.release),
    status: TaskStatus.failed,
    createdAt: galleryYesterday(18, 19),
  ),
  _buildGalleryTask(
    id: GalleryTaskIds.writeApiDocs,
    title: 'Write the v2 API docs',
    projectId: GalleryProjectIds.docs,
    doer: const OneAgentDoer(AgentKind.geminiCli),
    status: TaskStatus.done,
    createdAt: galleryYesterday(11, 39),
  ),
  _buildGalleryTask(
    id: GalleryTaskIds.renameBillingModule,
    title: 'Rename the billing module',
    projectId: GalleryProjectIds.acmeApp,
    doer: const OneAgentDoer(AgentKind.claudeCode),
    status: TaskStatus.done,
    createdAt: galleryDaysAgo(2),
  ),
]);

final List<Task> galleryJobs = List<Task>.unmodifiable(<Task>[
  _buildGalleryTask(
    id: GalleryTaskIds.nightlyTests,
    title: 'Nightly tests',
    projectId: GalleryProjectIds.acmeApp,
    doer: const WorkflowDoer(GalleryWorkflowIds.nightlyTests),
    schedule: DailySchedule(at: ScheduleTime(hour: 2, minute: 0)),
    status: TaskStatus.done,
    createdAt: galleryDaysAgo(60),
  ),
  _buildGalleryTask(
    id: GalleryTaskIds.updateDependencies,
    title: 'Update dependencies',
    details:
        'Update npm and Swift packages.\n'
        'Open a pull request with the changes.',
    projectId: GalleryProjectIds.acmeApp,
    doer: const OneAgentDoer(AgentKind.claudeCode),
    skills: const <SkillId>[GallerySkillIds.codeReview],
    schedule: WeeklySchedule(
      on: Weekday.monday,
      at: ScheduleTime(hour: 9, minute: 0),
    ),
    status: TaskStatus.failed,
    createdAt: galleryDaysAgo(50),
  ),
  _buildGalleryTask(
    id: GalleryTaskIds.retrainRanker,
    title: 'Retrain the ranker',
    projectId: GalleryProjectIds.mlRanker,
    doer: const WorkflowDoer(GalleryWorkflowIds.trainRanker),
    schedule: WeeklySchedule(
      on: Weekday.sunday,
      at: ScheduleTime(hour: 3, minute: 0),
    ),
    status: TaskStatus.done,
    createdAt: galleryDaysAgo(40),
  ),
  _buildGalleryTask(
    id: GalleryTaskIds.publishDocs,
    title: 'Publish the docs',
    projectId: GalleryProjectIds.docs,
    doer: const WorkflowDoer(GalleryWorkflowIds.docsSync),
    schedule: DailySchedule(at: ScheduleTime(hour: 18, minute: 0)),
    status: TaskStatus.done,
    createdAt: galleryDaysAgo(30),
  ),
]);
