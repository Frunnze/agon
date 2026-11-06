import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/workflow_repository.dart';
import 'package:agent_orchestration/data/rules/workflow_edits.dart'
    as workflow_edits;
import 'package:agent_orchestration/data/rules/workflow_graph.dart';

final class WorkflowDiagramEditor {
  const WorkflowDiagramEditor({
    required WorkflowRepository workflowRepository,
    required WorkflowId workflowId,
  }) : _workflowRepository = workflowRepository,
       _workflowId = workflowId;

  final WorkflowRepository _workflowRepository;
  final WorkflowId _workflowId;

  Future<Workflow> addStep(WorkflowAgent blank) {
    final Workflow edited = workflow_edits.addAgent(
      _readWorkflow(),
      blank,
    );
    return _workflowRepository.saveWorkflow(edited);
  }

  Future<Workflow> changeAgent(WorkflowAgent agent) {
    final Workflow edited = workflow_edits.replaceAgent(
      _readWorkflow(),
      agent,
    );
    return _workflowRepository.saveWorkflow(edited);
  }

  Future<Workflow> moveAgent(
    WorkflowAgentId agentId,
    CanvasPosition position,
  ) {
    final Workflow workflow = _readWorkflow();
    final WorkflowAgent moved = workflow
        .findAgent(agentId)
        .copyWith(position: position);
    final Workflow edited = workflow_edits.replaceAgent(workflow, moved);
    return _workflowRepository.saveWorkflow(edited);
  }

  Future<Workflow> connect(AgentConnection connection) {
    final Workflow edited = connectAgents(_readWorkflow(), connection);
    return _workflowRepository.saveWorkflow(edited);
  }

  Future<Workflow> changeConnection(AgentConnection connection) {
    final Workflow edited = workflow_edits.replaceConnection(
      _readWorkflow(),
      connection,
    );
    return _workflowRepository.saveWorkflow(edited);
  }

  Future<Workflow> removeConnection(AgentConnection connection) {
    final Workflow edited = workflow_edits.removeConnection(
      _readWorkflow(),
      connection,
    );
    return _workflowRepository.saveWorkflow(edited);
  }

  Future<Workflow> removeAgent(WorkflowAgentId agentId) {
    final Workflow edited = workflow_edits.removeAgent(
      _readWorkflow(),
      agentId,
    );
    return _workflowRepository.saveWorkflow(edited);
  }

  Workflow _readWorkflow() {
    return _workflowRepository.findWorkflow(_workflowId);
  }
}
