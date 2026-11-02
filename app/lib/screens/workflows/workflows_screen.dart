import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';
import 'package:agent_orchestration/data/repository/workflow_repository.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/screens/shared/muted_note.dart';
import 'package:agent_orchestration/screens/workflows.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/app_page.dart';
import 'package:agent_orchestration/widgets/empty_state.dart';
import 'package:agent_orchestration/widgets/lists/list_column.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';
import 'package:agent_orchestration/widgets/lists/list_row_main.dart';
import 'package:agent_orchestration/widgets/lists/responsive_list.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

const List<String> _columnLabels = <String>[
  'Workflow',
  'Available in',
  'Last used',
  'Signature',
];

AppRoute findWorkflowRoute(WorkflowId workflowId, SignatureState state) {
  switch (state) {
    case SignatureState.signed:
      return WorkflowDetailRoute(workflowId);
    case SignatureState.notSignedYet:
      return WorkflowBuilderRoute(
        workflowId,
        opening: BuilderOpening.forEditing,
      );
    case SignatureState.changedNotSigned:
      return WorkflowChangeRoute(workflowId);
  }
}

class WorkflowsScreen extends StatelessWidget {
  const WorkflowsScreen({
    required this.workflowRepository,
    required this.workspaceRepository,
    required this.taskRepository,
    required this.clock,
    required this.navigation,
    super.key,
  });

  final WorkflowRepository workflowRepository;
  final WorkspaceRepository workspaceRepository;
  final TaskRepository taskRepository;
  final Clock clock;
  final AppNavigation navigation;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        workflowRepository,
        workspaceRepository,
        taskRepository,
      ]),
      builder: _buildPage,
    );
  }

  Widget _buildPage(BuildContext context, Widget? _) {
    final List<Workflow> workflows = workflowRepository.listWorkflows();

    if (workflows.isEmpty) {
      return AppPage(
        children: <Widget>[
          const PageHeader(title: 'Workflows'),
          EmptyState(
            title: 'No workflows yet',
            message:
                'Describe what a chain of agents should do and an agent '
                'drafts the workflow for you.',
            action: _buildNewWorkflowButton(),
          ),
        ],
      );
    }

    final List<Workspace> workspaces = workspaceRepository.listWorkspaces();
    return AppPage(
      children: <Widget>[
        PageHeader(
          title: 'Workflows',
          summary: const <TextSegment>[
            TextSegment(
              'Available in all your workspaces unless you limit it.',
            ),
          ],
          actions: <Widget>[_buildNewWorkflowButton()],
        ),
        ResponsiveList(
          columns: buildStandardColumns(_columnLabels),
          rows: <ListRowData>[
            for (final Workflow workflow in workflows)
              _buildRow(workflow, workspaces),
          ],
        ),
        const MutedNote(
          'Runners only run versions signed with one of your keys.',
        ),
      ],
    );
  }

  Widget _buildNewWorkflowButton() {
    return AppButton.primary(
      label: 'New workflow',
      icon: AppIconKind.plus,
      onPressed: () => navigation.openRoute(const NewWorkflowRoute()),
    );
  }

  ListRowData _buildRow(Workflow workflow, List<Workspace> workspaces) {
    final SignatureState state = findSignatureState(
      workflow,
      workflowRepository.findPendingChange(workflow.id),
    );
    final DateTime? lastUsedAt = findLastWorkflowUse(
      workflowId: workflow.id,
      tasks: taskRepository.listTasks(),
      listRuns: taskRepository.listRuns,
    );

    return ListRowData(
      key: ValueKey<WorkflowId>(workflow.id),
      main: ListRowMain.monospace(
        title: workflow.name,
        subtitle: <TextSegment>[TextSegment(describeAgentNames(workflow))],
      ),
      meta: <Widget>[
        Text(describeAvailability(workflow.availability, workspaces)),
        Text(describeLastUse(lastUsedAt, clock.now())),
      ],
      end: buildSignatureLabel(state),
      onTap: () => navigation.openRoute(findWorkflowRoute(workflow.id, state)),
    );
  }
}
