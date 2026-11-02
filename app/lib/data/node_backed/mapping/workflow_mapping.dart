import 'package:agent_orchestration/bridge/codecs/workflow_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/workflow_views.dart' as node;
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

const String _documentLineBreak = '\n';

String readSignedDocument(node.WorkflowView view) {
  if (view.changes.isEmpty) {
    return view.document;
  }

  final StringBuffer signedDocument = StringBuffer();
  for (final node.DiffLine line in view.changes) {
    if (line.change != node.DiffLineChange.added) {
      signedDocument.write(line.text);
      signedDocument.write(_documentLineBreak);
    }
  }
  return signedDocument.toString();
}

WorkflowSignature? _mapSignatureFromNode(node.WorkflowView view) {
  final node.WorkflowSignature? signature = view.workflow.signature;
  if (signature == null) {
    return null;
  }

  final DateTime? signedAt = view.signedAt;
  if (signedAt == null) {
    throw FormatException(
      'the node sent signed workflow ${view.workflow.id} without signed_at',
    );
  }
  return WorkflowSignature(
    signedBy: signature.signedBy,
    signature: signature.signature,
    signedDocument: readSignedDocument(view),
    signedAt: signedAt,
  );
}

Workflow mapWorkflowFromNode(node.WorkflowView view) {
  final node.Workflow workflow = view.workflow;
  final List<WorkflowAgent> agents = <WorkflowAgent>[
    for (final node.WorkflowAgent agent in workflow.agents)
      mapWorkflowAgentFromNode(agent),
  ];
  final List<AgentConnection> connections = <AgentConnection>[
    for (final node.AgentConnection connection in workflow.connections)
      mapAgentConnectionFromNode(connection),
  ];

  return Workflow(
    id: workflow.id,
    name: workflow.name,
    availability: mapWorkspaceScopeFromNode(workflow.availability),
    agents: agents,
    connections: connections,
    signature: _mapSignatureFromNode(view),
  );
}

node.Workflow mapWorkflowToNode(Workflow workflow) {
  final List<node.WorkflowAgent> agents = <node.WorkflowAgent>[
    for (final WorkflowAgent agent in workflow.agents)
      mapWorkflowAgentToNode(agent),
  ];
  final List<node.AgentConnection> connections = <node.AgentConnection>[
    for (final AgentConnection connection in workflow.connections)
      mapAgentConnectionToNode(connection),
  ];

  return node.Workflow(
    id: workflow.id,
    name: workflow.name,
    availability: mapWorkspaceScopeToNode(workflow.availability),
    agents: agents,
    connections: connections,
    signature: null,
  );
}
