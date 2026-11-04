import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_library.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_runners.dart';
import 'package:agent_orchestration/data/gallery/gallery_tasks.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/rules/schedule_rules.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/task_form/task_form_options.dart';
import 'package:agent_orchestration/screens/task_form/task_form_values.dart';
import 'package:agent_orchestration/widgets/forms/select_entry.dart';

import '../support/random_inputs.dart';
import '../support/sample_records.dart';

TaskFormOptions buildGalleryOptions(RunnerTarget chosenTarget) {
  return buildTaskFormOptions(
    projects: galleryProjects.take(3).toList(),
    workflows: galleryWorkflows,
    runners: galleryRunners,
    deviceNames: DeviceNames(galleryDevices),
    skills: gallerySkills,
    chosenTarget: chosenTarget,
  );
}

TaskFormValues randomFormValues(Random random) {
  return TaskFormValues.blank(
    projectId: pickOne(random, sampleProjectIds),
    doer: defaultTaskDoer,
    repeat: pickOne(random, RepeatChoice.values),
  ).copyWith(
    title: randomWordPhrase(random),
    details: randomText(random),
    doer: randomTaskDoer(random),
    weekday: pickOne(random, Weekday.values),
    timeText: random.nextBool()
        ? formatScheduleTime(randomScheduleTime(random))
        : randomText(random),
  );
}

void main() {
  test('test_build_task_form_options_property_chosen_target_listed', () {
    final Random random = seededRandom(5001);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RunnerTarget target = randomRunnerTarget(random);
      final TaskFormOptions options = buildGalleryOptions(target);
      final List<RunnerTarget> values = <RunnerTarget>[
        for (final SelectOption<RunnerTarget> option in options.runners)
          option.value,
      ];

      expect(values.where((RunnerTarget v) => v == target).length, 1);
      expect(options.runners.first.label, 'Any free runner');
    }
  });

  test(
    'test_build_task_form_options_property_unsigned_workflows_disabled',
    () {
      final TaskFormOptions options = buildGalleryOptions(
        const AnyFreeRunner(),
      );
      final List<String> labels = <String>[];

      for (final SelectEntry<TaskDoer> entry in options.doers) {
        if (entry is SelectOption<TaskDoer>) {
          labels.add(entry.label);
          final bool isUnsigned = entry.label.endsWith('not signed yet');
          expect(entry.isEnabled, !isUnsigned);
        }
      }
      expect(labels, <String>[
        'Claude Code',
        'Codex',
        'Gemini CLI',
        'release',
        'nightly-tests',
        'feature-pipeline, not signed yet',
        'train-ranker',
        'docs-sync',
      ]);
    },
  );

  test('test_describe_skills_property_round_trips_through_find_skill_id', () {
    final Random random = seededRandom(5003);
    final TaskFormOptions options = buildGalleryOptions(const AnyFreeRunner());

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<SkillId> chosen = <SkillId>[
        for (final Skill skill in gallerySkills)
          if (random.nextBool()) skill.id,
      ];
      final List<String> names = options.describeSkills(chosen);
      final List<SkillId> back = names.map(options.findSkillId).toList();

      expect(back.toSet(), chosen.toSet());
    }
    expect(() => options.findSkillId('missing'), throwsArgumentError);
  });

  test('test_first_project_id_property_needs_a_project', () {
    final TaskFormOptions options = buildGalleryOptions(const AnyFreeRunner());
    final TaskFormOptions empty = buildTaskFormOptions(
      projects: const <Project>[],
      workflows: galleryWorkflows,
      runners: galleryRunners,
      deviceNames: DeviceNames(galleryDevices),
      skills: gallerySkills,
      chosenTarget: const AnyFreeRunner(),
    );

    expect(options.firstProjectId, galleryProjects.first.id);
    expect(() => empty.firstProjectId, throwsStateError);
  });

  test('test_from_task_property_schedule_round_trips_through_to_schedule', () {
    final Random random = seededRandom(5005);
    final List<Task> tasks = <Task>[...galleryTasks, ...galleryJobs];

    for (int i = 0; i < propertyIterations; i += 1) {
      final Task task = pickOne(random, tasks);
      final TaskFormValues values = TaskFormValues.fromTask(task);
      final Schedule? original = task.schedule;
      final Schedule? rebuilt = values.toSchedule();

      expect(values.title, task.title);
      expect(values.toTaskDraft().skills, task.skills);
      expect(rebuilt?.runtimeType, original?.runtimeType);
      if (original is WeeklySchedule && rebuilt is WeeklySchedule) {
        expect(rebuilt.on, original.on);
        expect(
          formatScheduleTime(rebuilt.at),
          formatScheduleTime(original.at),
        );
      }
    }
  });

  test('test_copy_with_property_changes_only_named_fields', () {
    final Random random = seededRandom(5006);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskFormValues values = randomFormValues(random);
      final String title = randomText(random);
      final TaskFormValues changed = values.copyWith(title: title);

      expect(changed.title, title);
      expect(changed.details, values.details);
      expect(changed.repeat, values.repeat);
      expect(changed.skillIds, values.skillIds);
    }
  });

  test('test_blank_property_new_work_follows_the_project', () {
    final Random random = seededRandom(5011);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskFormValues blank = TaskFormValues.blank(
        projectId: pickOne(random, sampleProjectIds),
        doer: randomTaskDoer(random),
        repeat: pickOne(random, RepeatChoice.values),
      );

      expect(blank.approvalPolicy, isNull);
      expect(blank.toDraftedWork().approvalPolicy, isNull);
    }
  });

  test('test_with_approval_policy_property_changes_only_the_policy', () {
    final Random random = seededRandom(5012);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskFormValues values = randomFormValues(random);
      final ApprovalPolicy? chosen = randomInheritableApprovalPolicy(random);

      final TaskFormValues changed = values.withApprovalPolicy(chosen);

      expect(changed.approvalPolicy, chosen);
      expect(changed.title, values.title);
      expect(changed.details, values.details);
      expect(changed.projectId, values.projectId);
      expect(changed.doer, values.doer);
      expect(changed.repeat, values.repeat);
      expect(changed.timeText, values.timeText);
      expect(changed.skillIds, values.skillIds);
    }
  });

  test('test_describe_title_problem_property_blank_titles_rejected', () {
    final Random random = seededRandom(5007);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskFormValues values = randomFormValues(random);
      final bool isBlank = values.title.trim().isEmpty;

      expect(values.describeTitleProblem() != null, isBlank);
      if (isBlank) {
        expect(values.isValid, isFalse);
      }
    }
  });

  test('test_describe_time_problem_property_only_timed_repeats_checked', () {
    final Random random = seededRandom(5008);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskFormValues values = randomFormValues(random);
      final bool hasValidTime = parseScheduleTime(values.timeText) != null;
      final bool expectsProblem = values.repeat.needsTime && !hasValidTime;

      expect(values.describeTimeProblem() != null, expectsProblem);
    }
  });

  test('test_to_schedule_property_valid_values_always_build', () {
    final Random random = seededRandom(5009);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskFormValues values = randomFormValues(random);
      if (!values.isValid) {
        continue;
      }
      final Schedule? schedule = values.toSchedule();

      expect(schedule == null, values.repeat == RepeatChoice.none);
      expect(values.toTaskDraft().title, values.title.trim());
    }
    final TaskFormValues broken = TaskFormValues.blank(
      projectId: sampleProjectIds.first,
      doer: defaultTaskDoer,
      repeat: RepeatChoice.daily,
    ).copyWith(timeText: 'later');
    expect(broken.toSchedule, throwsFormatException);
    expect(galleryNow.isUtc, isFalse);
  });
}
