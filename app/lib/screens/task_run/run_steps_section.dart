import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/run_text.dart';
import 'package:agent_orchestration/presentation/step_text.dart';
import 'package:agent_orchestration/screens/shared/status_labels.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';
import 'package:agent_orchestration/widgets/lists/list_row_main.dart';
import 'package:agent_orchestration/widgets/lists/responsive_list.dart';
import 'package:agent_orchestration/widgets/page_section.dart';

const Set<StepStatus> _highlightedStatuses = <StepStatus>{
  StepStatus.running,
  StepStatus.waitingForApproval,
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

class RunStepsSection extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final RunStep currentStep = findCurrentStep(run);

    return PageSection(
      title: 'Steps',
      children: <Widget>[
        ResponsiveList.plain(
          rows: <ListRowData>[
            for (final RunStep step in run.steps)
              ListRowData(
                main: ListRowMain.monospace(
                  title: step.name,
                  subtitle: describeStepSubtitle(
                    step: step,
                    target: findStepTarget(
                      step: step,
                      task: task,
                      workflow: workflow,
                    ),
                    deviceNames: deviceNames,
                    now: now,
                  ),
                ),
                end: buildStepStatusLabel(step.status),
                emphasis:
                    identical(step, currentStep) &&
                        _highlightedStatuses.contains(step.status)
                    ? RowEmphasis.current
                    : RowEmphasis.normal,
              ),
          ],
        ),
      ],
    );
  }
}
