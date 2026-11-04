import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/person_step.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/approval_repository.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';
import 'package:agent_orchestration/data/repository/person_step_repository.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/data/repository/runner_repository.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';
import 'package:agent_orchestration/data/repository/workflow_repository.dart';
import 'package:agent_orchestration/data/rules/kept_branches.dart';
import 'package:agent_orchestration/data/rules/place_offers.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/doer_text.dart';
import 'package:agent_orchestration/presentation/run_text.dart';
import 'package:agent_orchestration/screens/shared/agent_login_pointer.dart';
import 'package:agent_orchestration/screens/shared/live_run_watch.dart';
import 'package:agent_orchestration/screens/shared/person_step_questions.dart';
import 'package:agent_orchestration/screens/task_run/no_place_banner.dart';
import 'package:agent_orchestration/screens/task_run/not_pushed_banner.dart';
import 'package:agent_orchestration/screens/task_run/run_failure_banner.dart';
import 'package:agent_orchestration/screens/task_run/run_log_section.dart';
import 'package:agent_orchestration/screens/task_run/run_page_header.dart';
import 'package:agent_orchestration/screens/task_run/run_steps_section.dart';
import 'package:agent_orchestration/screens/task_run/run_summary.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/app_page.dart';
import 'package:agent_orchestration/widgets/split_layout.dart';
import 'package:agent_orchestration/windows/run_window_opener.dart';

class TaskRunScreen extends StatelessWidget {
  const TaskRunScreen({
    required this.runId,
    required this.taskRepository,
    required this.workflowRepository,
    required this.projectRepository,
    required this.deviceRepository,
    required this.approvalRepository,
    required this.personStepRepository,
    required this.runnerRepository,
    required this.clock,
    required this.navigation,
    required this.runWindowOpener,
    super.key,
  });

  final RunId runId;
  final TaskRepository taskRepository;
  final WorkflowRepository workflowRepository;
  final ProjectRepository projectRepository;
  final DeviceRepository deviceRepository;
  final ApprovalRepository approvalRepository;
  final PersonStepRepository personStepRepository;
  final RunnerRepository runnerRepository;
  final Clock clock;
  final AppNavigation navigation;
  final RunWindowOpener? runWindowOpener;

  @override
  Widget build(BuildContext context) {
    return LiveRunWatch(
      runId: runId,
      taskRepository: taskRepository,
      child: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[
          taskRepository,
          workflowRepository,
          projectRepository,
          deviceRepository,
          approvalRepository,
          personStepRepository,
          runnerRepository,
        ]),
        builder: _buildPage,
      ),
    );
  }

  Widget _buildPage(BuildContext context, Widget? _) {
    final Run run = taskRepository.findRun(runId);
    final Task task = taskRepository.findTask(run.taskId);
    final Workflow? workflow = findWorkflowForDoer(
      task.doer,
      workflowRepository.listWorkflows(),
    );
    final DeviceNames deviceNames = DeviceNames(
      deviceRepository.listDevices(),
    );
    final DateTime now = clock.now();
    final RunFailure? failure = run.failure;
    final List<KeptBranch> keptBranches = findKeptBranches(
      run: run,
      approvals: approvalRepository.listApprovals(),
    );
    final String runLabel = describeRunLabel(
      task: task,
      workflow: workflow,
      run: run,
    );

    return AppPage(
      children: <Widget>[
        RunPageHeader(
          run: run,
          task: task,
          runLabel: runLabel,
          summary: describeRunSummary(
            run: run,
            task: task,
            projectRepository: projectRepository,
            now: now,
          ),
          taskRepository: taskRepository,
          navigation: navigation,
          runWindowOpener: runWindowOpener,
        ),
        if (isWaitingForPlace(
          run: run,
          place: task.agentPlace,
          runners: runnerRepository.listRunners(),
        ))
          NoPlaceBanner(place: task.agentPlace),
        if (failure != null)
          RunFailureBanner(
            failure: failure,
            deviceNames: deviceNames,
            loginPointer: pointToAgentLogin(
              reason: failure.reason,
              runner: failure.runner,
              deviceRepository: deviceRepository,
              navigation: navigation,
            ),
          ),
        if (keptBranches.isNotEmpty)
          NotPushedBanner(
            keptBranches: keptBranches,
            deviceNames: deviceNames,
            onBrowse: _offerBranchBrowsing(task),
          ),
        for (final OpenPersonStep question in findQuestionsForRun(
          personStepRepository.listOpenPersonSteps(),
          run.id,
        ))
          _buildQuestionCard(question, run, workflow, now),
        SplitLayout(
          start: RunStepsSection(
            run: run,
            task: task,
            workflow: workflow,
            deviceNames: deviceNames,
            now: now,
          ),
          end: RunLogSection(
            run: run,
            deviceNames: deviceNames,
            thisDevice: deviceRepository.currentDevice(),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionCard(
    OpenPersonStep question,
    Run run,
    Workflow? workflow,
    DateTime now,
  ) {
    final PersonStepQuestions builder = PersonStepQuestions(
      taskRepository: taskRepository,
      workflowRepository: workflowRepository,
      personStepRepository: personStepRepository,
    );
    return builder.buildCardOnRunPage(
      openStep: question,
      run: run,
      workflow: workflow,
      now: now,
    );
  }

  ValueChanged<KeptBranch>? _offerBranchBrowsing(Task task) {
    if (!canLeaveRun(navigation)) {
      return null;
    }
    return (KeptBranch kept) => _browseKeptBranch(task, kept);
  }

  void _browseKeptBranch(Task task, KeptBranch kept) {
    navigation.openRoute(
      ProjectFilesRoute(
        projectId: task.projectId,
        repositoryAddress: kept.repositoryAddress,
        branch: kept.branch,
        preferredRunnerId: kept.runner,
      ),
    );
  }
}
