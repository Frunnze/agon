import 'dart:math';

import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';

import 'random_inputs.dart';

const List<ProjectId> sampleProjectIds = <ProjectId>[
  GalleryProjectIds.acmeApp,
  GalleryProjectIds.mlRanker,
  GalleryProjectIds.docs,
];

const List<WorkflowId> sampleWorkflowIds = <WorkflowId>[
  GalleryWorkflowIds.release,
  GalleryWorkflowIds.nightlyTests,
  GalleryWorkflowIds.featurePipeline,
  GalleryWorkflowIds.trainRanker,
  GalleryWorkflowIds.docsSync,
];

const List<SkillId> sampleSkillIds = <SkillId>[
  GallerySkillIds.iosRelease,
  GallerySkillIds.codeReview,
  GallerySkillIds.gitCleanup,
  GallerySkillIds.writeTests,
];

TaskDoer randomTaskDoer(Random random) {
  if (random.nextBool()) {
    return OneAgentDoer(pickOne(random, AgentKind.values));
  }
  return WorkflowDoer(pickOne(random, sampleWorkflowIds));
}

RunnerTarget randomRunnerTarget(Random random) {
  return pickOne<RunnerTarget>(random, <RunnerTarget>[
    const AnyFreeRunner(),
    const SpecificRunner(GalleryDeviceIds.macStudio),
    RunnerWithLabels(const <String>['gpu']),
  ]);
}

TaskDraft randomTaskDraft(Random random) {
  final List<SkillId> skills = <SkillId>[];
  for (final SkillId skillId in sampleSkillIds) {
    if (random.nextBool()) {
      skills.add(skillId);
    }
  }

  return TaskDraft(
    title: randomWordPhrase(random),
    details: randomText(random),
    projectId: pickOne(random, sampleProjectIds),
    doer: randomTaskDoer(random),
    runsOn: randomRunnerTarget(random),
    skills: skills,
    usesAutomaticSkills: random.nextBool(),
    approvalPolicy: pickOne(random, ApprovalPolicy.values),
  );
}

ScheduleTime randomScheduleTime(Random random) {
  return ScheduleTime(
    hour: random.nextInt(Duration.hoursPerDay),
    minute: random.nextInt(Duration.minutesPerHour),
  );
}

Schedule randomJobSchedule(Random random) {
  return pickOne<Schedule>(random, <Schedule>[
    HourlySchedule(minute: random.nextInt(Duration.minutesPerHour)),
    DailySchedule(at: randomScheduleTime(random)),
    WeeklySchedule(
      on: pickOne(random, Weekday.values),
      at: randomScheduleTime(random),
    ),
  ]);
}
