import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/presentation/count_text.dart';
import 'package:agent_orchestration/screens/projects.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';
import 'package:agent_orchestration/widgets/lists/list_row_main.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

final class ProjectWork {
  ProjectWork({required List<Task> tasks, required List<Run> runs})
    : tasks = List<Task>.unmodifiable(tasks),
      runs = List<Run>.unmodifiable(runs);

  final List<Task> tasks;
  final List<Run> runs;

  int get runningTaskCount {
    int count = 0;
    for (final Task task in tasks) {
      if (task.status == TaskStatus.running) {
        count += 1;
      }
    }
    return count;
  }

  Run? get latestRun {
    Run? latest;
    for (final Run run in runs) {
      if (latest == null || run.startedAt.isAfter(latest.startedAt)) {
        latest = run;
      }
    }
    return latest;
  }

  String? get latestTaskTitle {
    final Run? run = latestRun;
    if (run == null) {
      return null;
    }
    for (final Task task in tasks) {
      if (task.id == run.taskId) {
        return task.title;
      }
    }
    return null;
  }
}

ProjectWork collectProjectWork({
  required ProjectId projectId,
  required List<Task> tasks,
  required List<Run> Function(TaskId taskId) listRuns,
}) {
  final List<Task> projectTasks = <Task>[];
  final List<Run> projectRuns = <Run>[];

  for (final Task task in tasks) {
    if (task.projectId == projectId) {
      projectTasks.add(task);
      projectRuns.addAll(listRuns(task.id));
    }
  }

  return ProjectWork(tasks: projectTasks, runs: projectRuns);
}

String describeProjectSummary(Project project, ProjectWork work) {
  final String repositories = describeCount(
    project.repositories.length,
    singular: 'repo',
    plural: 'repos',
  );
  final String tasks = describeCount(
    work.tasks.length,
    singular: 'task',
    plural: 'tasks',
  );

  return '$repositories · $tasks';
}

ListRowData buildProjectRow({
  required Project project,
  required ProjectWork work,
  required DateTime now,
  required VoidCallback onTap,
}) {
  return ListRowData(
    key: ValueKey<ProjectId>(project.id),
    main: ListRowMain.monospace(
      title: project.name,
      subtitle: <TextSegment>[
        TextSegment.monospace(describeRepositoryPaths(project)),
      ],
    ),
    meta: <Widget>[
      Text(
        describeCount(
          project.repositories.length,
          singular: 'repo',
          plural: 'repos',
        ),
      ),
      Text(
        describeCount(work.tasks.length, singular: 'task', plural: 'tasks'),
      ),
    ],
    end: buildProjectActivityLabel(
      runningTaskCount: work.runningTaskCount,
      lastRunAt: work.latestRun?.startedAt,
      now: now,
    ),
    onTap: onTap,
  );
}
