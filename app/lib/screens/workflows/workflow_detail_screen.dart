import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/data/repository/runner_repository.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';
import 'package:agent_orchestration/data/repository/workflow_repository.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/data/rules/workflow_graph.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/shared/deletion_prompts.dart';
import 'package:agent_orchestration/screens/shared/deletion_review.dart';
import 'package:agent_orchestration/screens/shared/muted_note.dart';
import 'package:agent_orchestration/screens/workflows.dart';
import 'package:agent_orchestration/screens/workflows/workflow_quick_start.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/app_page.dart';
import 'package:agent_orchestration/widgets/code_block.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';
import 'package:agent_orchestration/widgets/lists/list_row_main.dart';
import 'package:agent_orchestration/widgets/lists/responsive_list.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/page_header.dart';
import 'package:agent_orchestration/widgets/page_section.dart';
import 'package:agent_orchestration/widgets/split_layout.dart';

const SectionRoute _workflowsRoute = SectionRoute(AppSection.workflows);

class WorkflowDetailScreen extends StatelessWidget {
  const WorkflowDetailScreen({
    required this.workflowId,
    required this.workflowRepository,
    required this.workspaceRepository,
    required this.deviceRepository,
    required this.runnerRepository,
    required this.projectRepository,
    required this.taskRepository,
    required this.clock,
    required this.navigation,
    super.key,
  });

  final WorkflowId workflowId;
  final WorkflowRepository workflowRepository;
  final WorkspaceRepository workspaceRepository;
  final DeviceRepository deviceRepository;
  final RunnerRepository runnerRepository;
  final ProjectRepository projectRepository;
  final TaskRepository taskRepository;
  final Clock clock;
  final AppNavigation navigation;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        workflowRepository,
        runnerRepository,
        deviceRepository,
      ]),
      builder: _buildPage,
    );
  }

  Widget _buildPage(BuildContext context, Widget? _) {
    final Workflow workflow = workflowRepository.findWorkflow(workflowId);
    final DeviceNames deviceNames = DeviceNames(
      deviceRepository.listDevices(),
    );
    final WorkflowSignature? signature = workflow.signature;

    return AppPage(
      children: <Widget>[
        PageHeader(
          title: workflow.name,
          summary: <TextSegment>[
            TextSegment(
              describeSignedSummary(
                workflow: workflow,
                workspaces: workspaceRepository.listWorkspaces(),
                deviceNames: deviceNames,
                now: clock.now(),
              ),
            ),
          ],
          backLink: BackLink(
            label: 'Workflows',
            onPressed: () => navigation.returnTo(_workflowsRoute),
          ),
          actions: <Widget>[
            AppButton.secondary(
              label: 'Delete',
              onPressed: () => unawaited(_reviewDeletion(context, workflow)),
            ),
            AppButton.secondary(
              label: 'Edit diagram',
              icon: AppIconKind.edit,
              onPressed: () => navigation.openRoute(
                WorkflowBuilderRoute(
                  workflowId,
                  opening: BuilderOpening.forEditing,
                ),
              ),
            ),
            AppButton.secondary(
              label: 'Use in a task',
              icon: AppIconKind.tasks,
              onPressed: signature == null
                  ? null
                  : () =>
                        navigation.openRoute(NewWorkflowTaskRoute(workflowId)),
            ),
            AppButton.primary(
              label: startNowLabel,
              icon: AppIconKind.play,
              onPressed: signature == null
                  ? null
                  : () => unawaited(_startNow(workflow)),
            ),
          ],
        ),
        SplitLayout(
          start: PageSection(
            title: 'Steps',
            children: <Widget>[
              ResponsiveList.plain(
                rows: <ListRowData>[
                  for (final WorkflowAgent agent in orderAgents(workflow))
                    _buildStepRow(agent, deviceNames),
                ],
              ),
            ],
          ),
          end: PageSection(
            title: 'Source',
            children: <Widget>[
              if (signature == null)
                const MutedNote('Sign it to see the version runners use.')
              else
                CodeBlock(lines: splitDocumentLines(signature.signedDocument)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _reviewDeletion(BuildContext context, Workflow workflow) {
    return reviewDeletion(
      context: context,
      prompt: describeWorkflowDeletion(workflow),
      leavePage: () => navigation.returnTo(_workflowsRoute),
      deleteRecord: () => workflowRepository.deleteWorkflow(workflow.id),
    );
  }

  ListRowData _buildStepRow(WorkflowAgent agent, DeviceNames deviceNames) {
    final List<Runner> runners = runnerRepository.listRunners();

    return ListRowData(
      key: ValueKey<WorkflowAgentId>(agent.id),
      main: ListRowMain.monospace(
        title: agent.name,
        subtitle: describeStepRunsOn(agent.runsOn, deviceNames),
      ),
      end: buildRunnerMatchLabel(agent.runsOn, runners),
    );
  }

  Future<void> _startNow(Workflow workflow) async {
    final WorkspaceId workspaceId = workspaceRepository.currentWorkspace().id;
    final List<Project> projects = projectRepository.listProjects(workspaceId);
    if (projects.isEmpty) {
      navigation.openRoute(const NewProjectRoute());
      return;
    }

    final RunId runId = await startWorkflowNow(
      taskRepository: taskRepository,
      workflow: workflow,
      projectId: projects.first.id,
    );
    navigation.openRoute(TaskRunRoute(runId));
  }
}
