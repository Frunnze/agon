import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_library.dart';
import 'package:agent_orchestration/data/gallery/gallery_runners.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/chat/chat_context_panel.dart';
import 'package:agent_orchestration/screens/shared/status_labels.dart';
import 'package:agent_orchestration/screens/task_form/task_form_options.dart';
import 'package:agent_orchestration/screens/task_form/task_form_values.dart';
import 'package:agent_orchestration/theme/layout_size.dart';
import 'package:agent_orchestration/theme/page_metrics.dart';
import 'package:agent_orchestration/widgets/gaps.dart';
import 'package:agent_orchestration/widgets/status_label.dart';

import '../support/random_inputs.dart';
import '../support/sample_records.dart';
import '../support/widget_harness.dart';

void main() {
  test('test_build_task_status_label_property_only_failures_danger', () {
    for (final TaskStatus status in TaskStatus.values) {
      final StatusLabel label = buildTaskStatusLabel(status);
      expect(label.tone == StatusTone.danger, status == TaskStatus.failed);
      expect(label.text, isNotEmpty);
    }
  });

  test('test_build_job_last_run_label_property_done_reads_passed', () {
    for (final TaskStatus status in TaskStatus.values) {
      final StatusLabel label = buildJobLastRunLabel(status);
      expect(label.text == 'Passed', status == TaskStatus.done);
    }
  });

  test('test_build_step_status_label_property_waiting_reads_next', () {
    for (final StepStatus status in StepStatus.values) {
      final StatusLabel label = buildStepStatusLabel(status);
      expect(label.text == 'Next', status == StepStatus.waiting);
      expect(label.tone == StatusTone.danger, status == StepStatus.failed);
    }
  });

  test('test_describe_sandbox_property_every_kind_described', () {
    final Set<String> descriptions = <String>{
      for (final SandboxKind sandbox in SandboxKind.values)
        describeSandbox(sandbox),
    };
    expect(descriptions.length, SandboxKind.values.length);
    expect(
      describeSandbox(SandboxKind.container),
      'New container for this run. Sees only its workspace.',
    );
  });

  test('test_find_skill_id_property_every_skill_name_resolves', () {
    final Random random = seededRandom(7301);
    final TaskFormOptions options = buildTaskFormOptions(
      projects: galleryProjects,
      workflows: galleryWorkflows,
      runners: galleryRunners,
      deviceNames: DeviceNames(galleryDevices),
      skills: gallerySkills,
      chosenTarget: const AnyFreeRunner(),
    );

    for (int i = 0; i < propertyIterations; i += 1) {
      final Skill skill = pickOne(random, gallerySkills);
      expect(options.findSkillId(skill.name), skill.id);
      expect(
        () => options.findSkillId('${skill.name}${randomText(random)}x'),
        throwsArgumentError,
      );
    }
  });

  test('test_to_task_draft_property_trims_text_and_keeps_choices', () {
    final Random random = seededRandom(7302);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String title = randomText(random);
      final TaskDoer doer = randomTaskDoer(random);
      final TaskFormValues values = TaskFormValues.blank(
        projectId: pickOne(random, sampleProjectIds),
        doer: defaultTaskDoer,
        repeat: pickOne(random, RepeatChoice.values),
      ).copyWith(title: '  $title ', doer: doer);
      final TaskDraft draft = values.toTaskDraft();

      expect(draft.title, title.trim());
      expect(draft.doer, doer);
      expect(draft.projectId, values.projectId);
    }
    expect(AgentKind.values.length, 3);
  });

  test('test_page_gap_for_property_wider_layouts_never_tighter', () {
    expect(
      pageGapFor(LayoutSize.compact) <= pageGapFor(LayoutSize.medium),
      isTrue,
    );
    expect(
      pageGapFor(LayoutSize.medium) <= pageGapFor(LayoutSize.large),
      isTrue,
    );
  });

  test('test_space_horizontally_property_gaps_only_between_children', () {
    final Random random = seededRandom(7303);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int count = random.nextInt(9);
      final List<Widget> spaced = spaceHorizontally(<Widget>[
        for (int index = 0; index < count; index += 1) Text('$index'),
      ], 4);
      final int gaps = spaced.whereType<SizedBox>().length;

      expect(gaps, count == 0 ? 0 : count - 1);
    }
  });

  testWidgets('test_of_property_layout_size_follows_window_width', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(7304);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = randomWidth(random, least: 320, most: 1600);
      LayoutSize? measured;
      await pumpScrollableAtWidth(
        tester,
        width: width,
        child: _LayoutSizeProbe(
          onMeasured: (LayoutSize size) => measured = size,
        ),
      );

      expect(measured, LayoutSize.forWidth(width));
    }
  });
}

class _LayoutSizeProbe extends StatelessWidget {
  const _LayoutSizeProbe({required this.onMeasured});

  final ValueChanged<LayoutSize> onMeasured;

  @override
  Widget build(BuildContext context) {
    onMeasured(LayoutSize.of(context));
    return const SizedBox.shrink();
  }
}
