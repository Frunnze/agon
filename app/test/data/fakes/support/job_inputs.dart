import 'dart:math';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/schedule_rules.dart';

import '../../../support/random_inputs.dart';
import '../../../support/sample_records.dart';
import '../../../support/workflow_repositories.dart';
import 'notification_counter.dart';

const DeviceId jobTestThisDevice = DeviceId('this-device');
const int _largestRecordCount = 6;
const String _skillSeparator = ',';
const String _noScheduleText = 'no schedule';
const String _fieldSeparator = '\n';

typedef CountedJobs = ({
  FakeJobRepository repository,
  FakeTaskRepository taskRepository,
  NotificationCounter notifications,
  DateTime moment,
});

JobDraft randomJobDraft(Random random) {
  return JobDraft(
    task: randomTaskDraft(random),
    schedule: randomJobSchedule(random),
  );
}

Task randomStoredRecord(Random random, {required String identifier}) {
  return Task.fromDraft(
    id: TaskId(identifier),
    draft: randomTaskDraft(random),
    schedule: random.nextBool() ? null : randomJobSchedule(random),
    status: pickOne(random, TaskStatus.values),
    createdAt: randomUtcMoment(random),
  );
}

List<Task> randomStoredRecords(Random random) {
  final List<Task> records = <Task>[];
  final int count = random.nextInt(_largestRecordCount);
  for (int i = 0; i < count; i += 1) {
    final String identifier = 'stored-$i-${randomText(random)}';
    records.add(randomStoredRecord(random, identifier: identifier));
  }
  return records;
}

FakeTaskRepository buildJobTestTaskRepository(
  List<Task> records, {
  required DateTime moment,
}) {
  return FakeTaskRepository(
    tasks: records,
    runs: const <Run>[],
    clock: FixedClock(moment),
    currentDeviceId: jobTestThisDevice,
    workflowRepository: buildGalleryWorkflowRepository(),
  );
}

CountedJobs buildCountedJobRepository(Random random, List<Task> records) {
  final DateTime moment = randomUtcMoment(random);
  final FakeTaskRepository taskRepository = buildJobTestTaskRepository(
    records,
    moment: moment,
  );
  final FakeJobRepository repository = FakeJobRepository(
    taskRepository: taskRepository,
    clock: FixedClock(moment),
  );
  final NotificationCounter notifications = NotificationCounter();
  repository.addListener(notifications.record);
  return (
    repository: repository,
    taskRepository: taskRepository,
    notifications: notifications,
    moment: moment,
  );
}

List<String> describeTaskIds(List<Task> tasks) {
  final List<String> identifiers = <String>[];
  for (final Task task in tasks) {
    identifiers.add(task.id.value);
  }
  return identifiers;
}

String _describeDoer(TaskDoer doer) {
  switch (doer) {
    case OneAgentDoer(:final AgentKind agent):
      return 'agent ${agent.name}';
    case WorkflowDoer(:final WorkflowId workflowId):
      return 'workflow ${workflowId.value}';
  }
}

String describeJobContent(Task job) {
  final List<String> skillNames = <String>[
    for (final SkillId skillId in job.skills) skillId.value,
  ];
  final Schedule? schedule = job.schedule;
  final String scheduleText = schedule == null
      ? _noScheduleText
      : describeSchedule(schedule);
  return <Object?>[
    job.title,
    job.details,
    job.projectId.value,
    _describeDoer(job.doer),
    job.agentPlace,
    skillNames.join(_skillSeparator),
    job.usesAutomaticSkills,
    job.approvalPolicy,
    scheduleText,
    job.status,
  ].join(_fieldSeparator);
}

Future<void> changeRandomJobValidly(Random random, CountedJobs counted) async {
  final List<Task> jobs = counted.repository.listJobs();
  if (jobs.isEmpty || random.nextBool()) {
    await counted.repository.createJob(randomJobDraft(random));
    return;
  }
  final Task job = pickOne(random, jobs);
  if (random.nextBool()) {
    await counted.repository.updateJob(job.id, randomJobDraft(random));
    return;
  }
  await counted.repository.deleteJob(job.id);
}
