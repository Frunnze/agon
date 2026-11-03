import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';
import 'package:agent_orchestration/data/repository/job_repository.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/data/repository/skill_repository.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';
import 'package:agent_orchestration/data/repository/workflow_repository.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/data/rules/schedule_rules.dart';
import 'package:agent_orchestration/presentation/agent_place_text.dart';
import 'package:agent_orchestration/presentation/approval_policy_text.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/skill_names.dart';
import 'package:agent_orchestration/screens/new_items/draft_review.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/fact_list.dart';

const String unknownProjectText = 'Unknown project';
const String unknownWorkflowText = 'Unknown workflow';
const String anyFreeRunnerText = 'Any free runner';
const String automaticSkillsOnText = 'The agent may also pick them';
const String automaticSkillsOffText = 'Off';
const String startsAtOnceText = 'As soon as you approve';

String describeRunsOn(RunnerTarget target, DeviceNames deviceNames) {
  return switch (target) {
    AnyFreeRunner() => anyFreeRunnerText,
    SpecificRunner(:final DeviceId deviceId) => deviceNames.describeDevice(
      deviceId,
    ),
    RunnerWithLabels(:final List<String> labels) =>
      'Any runner with ${labels.join(', ')}',
  };
}

String describeApprovalPolicy(ApprovalPolicy policy) {
  final String title = describeApprovalPolicyTitle(policy);
  final String detail = describeApprovalPolicyDetail(policy);
  return '$title. $detail';
}

String describeRepeatingTask(Schedule schedule) {
  return '${describeSchedule(schedule)}, so it becomes a job';
}

final class WorkDraftReview implements DraftReview {
  const WorkDraftReview({
    required this.kind,
    required this.projectRepository,
    required this.workspaceRepository,
    required this.workflowRepository,
    required this.skillRepository,
    required this.deviceRepository,
    required this.taskRepository,
    required this.jobRepository,
    required this.navigation,
  });

  final DraftKind kind;
  final ProjectRepository projectRepository;
  final WorkspaceRepository workspaceRepository;
  final WorkflowRepository workflowRepository;
  final SkillRepository skillRepository;
  final DeviceRepository deviceRepository;
  final TaskRepository taskRepository;
  final JobRepository jobRepository;
  final AppNavigation navigation;

  @override
  List<Fact> describeFacts(DraftedItem item) {
    final DraftedWork work = _requireWork(item);
    final DeviceNames deviceNames = DeviceNames(
      deviceRepository.listDevices(),
    );
    final List<String> skillNames = describeSkillNames(
      skills: skillRepository.listSkills(),
      skillIds: work.skills,
    );

    return <Fact>[
      describeTextFact('What should be done', work.title),
      describeOptionalTextFact('Details', work.details),
      _describeProjectFact(work.projectId),
      describeTextFact('Who does it', _describeDoer(work.doer)),
      describeTextFact('Runs on', describeRunsOn(work.runsOn, deviceNames)),
      describeTextFact(agentPlaceTitle, describeTaskPlace(work.agentPlace)),
      if (skillNames.isEmpty)
        describeMutedFact('Skills to use', noneChosenText)
      else
        Fact.chips(term: 'Skills to use', chips: skillNames),
      describeTextFact(
        'Automatic skills',
        work.usesAutomaticSkills
            ? automaticSkillsOnText
            : automaticSkillsOffText,
      ),
      describeTextFact(
        approvalPolicyLabel,
        describeApprovalPolicy(work.approvalPolicy),
      ),
      _describeTimingFact(work.schedule),
    ];
  }

  @override
  Future<void> approve(DraftedItem item) async {
    final DraftedWork work = _requireWork(item);
    final Schedule? schedule = work.schedule;
    if (schedule != null) {
      await jobRepository.createJob(
        JobDraft(task: work.toTaskDraft(), schedule: schedule),
      );
      _openJobs();
      return;
    }
    if (kind == DraftKind.job) {
      throw StateError('The job ${work.title} has no schedule');
    }

    final Task task = await taskRepository.createTask(work.toTaskDraft());
    final Run run = await taskRepository.startTask(task.id);
    navigation.replaceRoute(TaskRunRoute(run.id));
  }

  void _openJobs() {
    if (kind == DraftKind.job) {
      navigation.closeRoute();
      return;
    }
    navigation.openSection(const SectionRoute(AppSection.jobs));
  }

  DraftedWork _requireWork(DraftedItem item) {
    if (item is! DraftedWork) {
      throw ArgumentError.value(item, 'item', 'Not a task or job draft');
    }
    return item;
  }

  Fact _describeProjectFact(ProjectId? projectId) {
    if (projectId == null) {
      return describeMutedFact('Project', notChosenText);
    }

    final WorkspaceId workspaceId = workspaceRepository.currentWorkspace().id;
    for (final Project project in projectRepository.listProjects(
      workspaceId,
    )) {
      if (project.id == projectId) {
        return describeTextFact('Project', project.name);
      }
    }
    return describeMutedFact('Project', unknownProjectText);
  }

  String _describeDoer(TaskDoer doer) {
    switch (doer) {
      case OneAgentDoer(:final AgentKind agent):
        return agent.label;
      case WorkflowDoer(:final WorkflowId workflowId):
        for (final Workflow workflow in workflowRepository.listWorkflows()) {
          if (workflow.id == workflowId) {
            return workflow.name;
          }
        }
        return unknownWorkflowText;
    }
  }

  Fact _describeTimingFact(Schedule? schedule) {
    if (schedule == null && kind == DraftKind.job) {
      return describeMutedFact('Repeats', notChosenText);
    }
    if (schedule == null) {
      return describeTextFact('Starts', startsAtOnceText);
    }
    if (kind == DraftKind.job) {
      return describeTextFact('Repeats', describeSchedule(schedule));
    }
    return describeTextFact('Repeats', describeRepeatingTask(schedule));
  }
}
