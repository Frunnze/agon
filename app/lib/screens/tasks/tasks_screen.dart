import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';
import 'package:agent_orchestration/data/repository/workflow_repository.dart';
import 'package:agent_orchestration/data/rules/task_summary.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/doer_text.dart';
import 'package:agent_orchestration/screens/tasks/task_row.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/app_page.dart';
import 'package:agent_orchestration/widgets/empty_state.dart';
import 'package:agent_orchestration/widgets/lists/list_column.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';
import 'package:agent_orchestration/widgets/lists/responsive_list.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

const List<String> _columnLabels = <String>[
  'Task',
  'Runs on',
  'Started',
  'Status',
];

class TasksScreen extends StatelessWidget {
  const TasksScreen({
    required this.taskRepository,
    required this.workflowRepository,
    required this.projectRepository,
    required this.deviceRepository,
    required this.clock,
    required this.navigation,
    super.key,
  });

  final TaskRepository taskRepository;
  final WorkflowRepository workflowRepository;
  final ProjectRepository projectRepository;
  final DeviceRepository deviceRepository;
  final Clock clock;
  final AppNavigation navigation;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        taskRepository,
        workflowRepository,
        projectRepository,
        deviceRepository,
      ]),
      builder: _buildPage,
    );
  }

  Widget _buildPage(BuildContext context, Widget? _) {
    final List<Task> tasks = taskRepository.listTasks();

    if (tasks.isEmpty) {
      return AppPage(
        children: <Widget>[
          const PageHeader(title: 'Tasks'),
          EmptyState(
            title: 'No tasks yet',
            message:
                'Write what you want done, then pick one agent or a whole '
                'workflow to do it.',
            action: _buildNewTaskButton(),
          ),
        ],
      );
    }

    return AppPage(
      children: <Widget>[
        PageHeader(
          title: 'Tasks',
          summary: <TextSegment>[TextSegment(describeTaskSummary(tasks))],
          actions: <Widget>[_buildNewTaskButton()],
        ),
        ResponsiveList(
          columns: buildStandardColumns(_columnLabels),
          rows: <ListRowData>[for (final Task task in tasks) _buildRow(task)],
        ),
      ],
    );
  }

  Widget _buildNewTaskButton() {
    return AppButton.primary(
      label: 'New task',
      icon: AppIconKind.plus,
      onPressed: () => navigation.openRoute(const NewTaskRoute()),
    );
  }

  ListRowData _buildRow(Task task) {
    final List<Run> runs = taskRepository.listRuns(task.id);
    final Run? latestRun = runs.isEmpty ? null : runs.first;

    return buildTaskRow(
      task: task,
      latestRun: latestRun,
      projectName: projectRepository.findProject(task.projectId).name,
      doerLabel: describeDoer(task.doer, workflowRepository.listWorkflows()),
      deviceNames: DeviceNames(deviceRepository.listDevices()),
      now: clock.now(),
      onTap: () => _openTask(task, latestRun),
    );
  }

  void _openTask(Task task, Run? latestRun) {
    if (latestRun == null || task.status == TaskStatus.toDo) {
      navigation.openRoute(EditTaskRoute(task.id));
    } else {
      navigation.openRoute(TaskRunRoute(latestRun.id));
    }
  }
}
