import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/task.dart';

abstract interface class JobRepository implements Listenable {
  List<Task> listJobs();

  Task findJob(TaskId jobId);

  Future<Task> createJob(JobDraft draft);

  Future<Task> updateJob(TaskId jobId, JobDraft draft);

  Future<void> deleteJob(TaskId jobId);
}
