import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';

const String blankWorkflowDescriptionProblem =
    'Describe what the workflow should do';

final class WorkflowDraft {
  const WorkflowDraft({required this.description});

  final String description;
}

final class PendingAgent {
  const PendingAgent({required this.name, required this.position});

  final String name;
  final CanvasPosition position;
}

final class WorkflowDraftProgress {
  WorkflowDraftProgress({
    required this.workflow,
    required List<PendingAgent> pendingAgents,
    required this.drafterKind,
    required this.drafterDeviceId,
  }) : pendingAgents = List<PendingAgent>.unmodifiable(pendingAgents);

  final Workflow workflow;
  final List<PendingAgent> pendingAgents;
  final AgentKind drafterKind;
  final DeviceId drafterDeviceId;

  bool get isFinished => pendingAgents.isEmpty;
}
