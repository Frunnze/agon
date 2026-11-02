import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/repository/job_repository.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

const String _jobKind = 'job';

final class FakeJobRepository implements JobRepository {
  FakeJobRepository({
    required FakeTaskRepository taskRepository,
    required Clock clock,
  }) : _taskRepository = taskRepository,
       _clock = clock;

  final FakeTaskRepository _taskRepository;
  final Clock _clock;
  int _createdJobCount = 0;

  @override
  void addListener(VoidCallback listener) {
    _taskRepository.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _taskRepository.removeListener(listener);
  }

  @override
  List<Task> listJobs() {
    return List<Task>.unmodifiable(<Task>[
      for (final Task task in _taskRepository.listTasksAndJobs())
        if (task.schedule != null) task,
    ]);
  }

  @override
  Task findJob(TaskId jobId) {
    return findRecord(
      listJobs(),
      matches: (Task job) => job.id == jobId,
      kind: _jobKind,
      identifier: jobId.value,
    );
  }

  @override
  Future<Task> createJob(JobDraft draft) async {
    _createdJobCount += 1;
    final Task job = Task.fromDraft(
      id: TaskId('created-job-$_createdJobCount'),
      draft: draft.task,
      schedule: draft.schedule,
      status: TaskStatus.toDo,
      createdAt: _clock.now(),
    );

    _taskRepository.storeTask(job);
    return job;
  }

  @override
  Future<Task> updateJob(TaskId jobId, JobDraft draft) async {
    final Task existing = _taskRepository.findTask(jobId);
    final Task updated = Task.fromDraft(
      id: existing.id,
      draft: draft.task,
      schedule: draft.schedule,
      status: existing.status,
      createdAt: existing.createdAt,
    );

    _taskRepository.storeTask(updated);
    return updated;
  }

  @override
  Future<void> deleteJob(TaskId jobId) async {
    findJob(jobId);
    await _taskRepository.deleteTask(jobId);
  }
}
