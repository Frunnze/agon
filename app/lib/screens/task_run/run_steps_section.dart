import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/run_text.dart';
import 'package:agent_orchestration/presentation/step_round_text.dart';
import 'package:agent_orchestration/presentation/step_text.dart';
import 'package:agent_orchestration/screens/shared/status_labels.dart';
import 'package:agent_orchestration/screens/task_run/earlier_rounds_block.dart';
import 'package:agent_orchestration/screens/task_run/run_notes_section.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';
import 'package:agent_orchestration/widgets/lists/list_row_main.dart';
import 'package:agent_orchestration/widgets/lists/responsive_list.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/page_section.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';

const String _separator = ' · ';

const Set<StepStatus> _highlightedStatuses = <StepStatus>{
  StepStatus.running,
  StepStatus.waitingForApproval,
  StepStatus.waitingForPerson,
  StepStatus.failed,
};

RunnerTarget findStepTarget({
  required RunStep step,
  required Task task,
  required Workflow? workflow,
}) {
  final WorkflowAgentId? agentId = step.agentId;
  if (agentId == null || workflow == null) {
    return task.runsOn;
  }
  return workflow.findAgent(agentId).runsOn;
}

class RunStepsSection extends StatefulWidget {
  const RunStepsSection({
    required this.run,
    required this.task,
    required this.workflow,
    required this.deviceNames,
    required this.now,
    super.key,
  });

  final Run run;
  final Task task;
  final Workflow? workflow;
  final DeviceNames deviceNames;
  final DateTime now;

  @override
  State<RunStepsSection> createState() => _RunStepsSectionState();
}

class _RunStepsSectionState extends State<RunStepsSection> {
  Set<String> _stepsShowingEarlierRounds = const <String>{};

  @override
  Widget build(BuildContext context) {
    final Run run = widget.run;
    final RunStep currentStep = findCurrentStep(run);

    return PageSection(
      title: 'Steps',
      children: <Widget>[
        ResponsiveList.plain(
          rows: <ListRowData>[
            for (final RunStep step in run.steps)
              ListRowData(
                key: ValueKey<String>(
                  '${step.name}-${_isShowingEarlierRounds(step)}',
                ),
                main: _buildStepMain(step),
                end: buildStepStatusLabel(step.status),
                emphasis:
                    identical(step, currentStep) &&
                        _highlightedStatuses.contains(step.status)
                    ? RowEmphasis.current
                    : RowEmphasis.normal,
              ),
          ],
        ),
        if (run.notes.isNotEmpty) RunNotesSection(notes: run.notes),
      ],
    );
  }

  Widget _buildStepMain(RunStep step) {
    final Widget rowMain = ListRowMain.monospace(
      title: step.name,
      subtitle: _describeSubtitle(step),
    );
    if (step.earlierRounds.isEmpty) {
      return rowMain;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        rowMain,
        const SizedBox(height: AppSpacing.space1),
        EarlierRoundsBlock(
          step: step,
          isShown: _isShowingEarlierRounds(step),
          onToggled: () => _toggleEarlierRounds(step),
        ),
      ],
    );
  }

  bool _isShowingEarlierRounds(RunStep step) {
    return _stepsShowingEarlierRounds.contains(step.name);
  }

  void _toggleEarlierRounds(RunStep step) {
    final Set<String> shownSteps = <String>{..._stepsShowingEarlierRounds};
    if (!shownSteps.remove(step.name)) {
      shownSteps.add(step.name);
    }
    setState(() => _stepsShowingEarlierRounds = shownSteps);
  }

  List<TextSegment> _describeSubtitle(RunStep step) {
    final List<TextSegment> base = describeStepSubtitle(
      step: step,
      target: findStepTarget(
        step: step,
        task: widget.task,
        workflow: widget.workflow,
      ),
      deviceNames: widget.deviceNames,
      now: widget.now,
    );
    final List<String?> extras = <String?>[
      describeStepRound(step: step, workflow: widget.workflow),
      describeStepOutcome(step.outcome),
    ];

    return <TextSegment>[
      ...base,
      for (final String? extra in extras)
        if (extra != null) TextSegment('$_separator$extra'),
    ];
  }
}
