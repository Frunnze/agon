import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/run_step_agents.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/run_text.dart';

const String _unassignedAgentName = 'Agent';
const String _personStepName = 'You';

final class ChatRunContext {
  ChatRunContext({
    required this.run,
    required this.task,
    required this.workflow,
    required DeviceNames deviceNames,
  }) : currentStep = findCurrentStep(run),
       _deviceNames = deviceNames;

  final Run run;
  final Task task;
  final Workflow? workflow;
  final RunStep currentStep;
  final DeviceNames _deviceNames;

  DeviceId? get runnerId => currentStep.runner;

  String get runLabel {
    return describeRunLabel(task: task, workflow: workflow, run: run);
  }

  String get runnerName {
    final DeviceId? runner = runnerId;
    if (runner == null) {
      return _unassignedAgentName;
    }
    return _deviceNames.nameOf(runner);
  }

  String get agentTitle {
    if (runnerId == null) {
      return _unassignedAgentName;
    }
    return 'Agent on $runnerName';
  }

  String get agentSummary {
    return '${_describeAgentKind()} · step ${currentStep.name}';
  }

  String _describeAgentKind() {
    final TaskDoer doer = task.doer;
    if (doer is OneAgentDoer) {
      return doer.agent.label;
    }

    final WorkflowAgent? agent = findRunStepAgent(
      step: currentStep,
      workflow: workflow,
    );
    if (agent == null) {
      return _unassignedAgentName;
    }
    if (agent.stepKind == StepKind.person) {
      return _personStepName;
    }
    return agent.kind?.label ?? _unassignedAgentName;
  }
}
