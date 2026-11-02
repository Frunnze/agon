import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/repository/job_repository.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/data/repository/workflow_repository.dart';
import 'package:agent_orchestration/data/rules/schedule_rules.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/doer_text.dart';
import 'package:agent_orchestration/presentation/time_phrases.dart';
import 'package:agent_orchestration/screens/shared/status_labels.dart';
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
  'Job',
  'Repeats',
  'Next run',
  'Last run',
];

class JobsScreen extends StatelessWidget {
  const JobsScreen({
    required this.jobRepository,
    required this.workflowRepository,
    required this.projectRepository,
    required this.clock,
    required this.navigation,
    super.key,
  });

  final JobRepository jobRepository;
  final WorkflowRepository workflowRepository;
  final ProjectRepository projectRepository;
  final Clock clock;
  final AppNavigation navigation;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        jobRepository,
        workflowRepository,
        projectRepository,
      ]),
      builder: _buildPage,
    );
  }

  Widget _buildPage(BuildContext context, Widget? _) {
    final List<Task> jobs = jobRepository.listJobs();

    if (jobs.isEmpty) {
      return AppPage(
        children: <Widget>[
          const PageHeader(title: 'Jobs'),
          EmptyState(
            title: 'No jobs yet',
            message:
                'A job is a task that repeats on a schedule, like nightly '
                'tests or a weekly dependency update.',
            action: _buildNewJobButton(),
          ),
        ],
      );
    }

    return AppPage(
      children: <Widget>[
        PageHeader(
          title: 'Jobs',
          summary: const <TextSegment>[
            TextSegment('Tasks that repeat on a schedule.'),
          ],
          actions: <Widget>[_buildNewJobButton()],
        ),
        ResponsiveList(
          columns: buildStandardColumns(_columnLabels),
          rows: <ListRowData>[for (final Task job in jobs) _buildRow(job)],
        ),
      ],
    );
  }

  Widget _buildNewJobButton() {
    return AppButton.primary(
      label: 'New job',
      icon: AppIconKind.plus,
      onPressed: () => navigation.openRoute(const NewJobRoute()),
    );
  }

  ListRowData _buildRow(Task job) {
    final Schedule? schedule = job.schedule;
    if (schedule == null) {
      throw StateError('Job ${job.title} has no schedule');
    }

    final DateTime now = clock.now();
    final String projectName = projectRepository
        .findProject(job.projectId)
        .name;
    final String doerLabel = describeDoer(
      job.doer,
      workflowRepository.listWorkflows(),
    );

    return ListRowData(
      key: ValueKey<TaskId>(job.id),
      main: ListRowMain(
        title: job.title,
        subtitle: <TextSegment>[TextSegment('$projectName · $doerLabel')],
      ),
      meta: <Widget>[
        Text(describeSchedule(schedule)),
        Text(describeUpcomingTime(findNextRunAfter(schedule, now), now)),
      ],
      end: buildJobLastRunLabel(job.status),
      onTap: () => navigation.openRoute(EditJobRoute(job.id)),
    );
  }
}
