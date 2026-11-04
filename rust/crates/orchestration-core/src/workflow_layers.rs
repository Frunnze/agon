use crate::identifiers::WorkflowAgentId;
use crate::workflow::{Workflow, WorkflowAgent};
use crate::workflow_graph::forward_connections;

pub(crate) const ONE_LAYER: usize = 1;
const TOP_LAYER: usize = 0;
const NO_ROWS: usize = 0;

pub(crate) struct ForwardLink {
    pub(crate) upstream_index: usize,
    pub(crate) downstream_index: usize,
    pub(crate) is_conditional: bool,
}

pub(crate) fn list_forward_links(workflow: &Workflow) -> Vec<ForwardLink> {
    let mut links = Vec::new();
    for connection in forward_connections(workflow) {
        let upstream = find_agent_index(&workflow.agents, connection.from);
        let downstream = find_agent_index(&workflow.agents, connection.to);
        if let (Some(upstream_index), Some(downstream_index)) =
            (upstream, downstream)
        {
            links.push(ForwardLink {
                upstream_index,
                downstream_index,
                is_conditional: connection.condition.is_some(),
            });
        }
    }
    links
}

fn find_agent_index(
    agents: &[WorkflowAgent],
    agent_id: WorkflowAgentId,
) -> Option<usize> {
    agents.iter().position(|agent| agent.id == agent_id)
}

pub(crate) fn assign_layers(
    agent_count: usize,
    links: &[ForwardLink],
) -> Vec<usize> {
    let mut layers = vec![TOP_LAYER; agent_count];
    for _ in 0..agent_count {
        for link in links {
            let below_upstream = layers[link.upstream_index] + ONE_LAYER;
            let current_layer = layers[link.downstream_index];
            layers[link.downstream_index] = current_layer.max(below_upstream);
        }
    }
    layers
}

pub(crate) fn count_rows(layers: &[usize]) -> usize {
    let deepest_layer = layers.iter().max();
    deepest_layer.map_or(NO_ROWS, |deepest| deepest + ONE_LAYER)
}

pub(crate) fn goes_down(link: &ForwardLink, layers: &[usize]) -> bool {
    layers[link.downstream_index] > layers[link.upstream_index]
}
