use std::collections::BTreeSet;

use orchestration_core::identifiers::WorkflowAgentId;
use orchestration_core::workflow::Workflow;
use orchestration_core::workflow_graph::{
    find_agent_by_id, forward_connections, forward_reachable_agents,
};
use orchestration_core::workflow_layout::lay_out_workflow;
use proptest::prelude::*;

use crate::branching_strategies::shuffled_fork_workflow;

const DRAWN_STEP_WIDTH: f64 = 160.0;

type BranchSteps = BTreeSet<WorkflowAgentId>;

#[derive(Clone, Copy, Debug)]
struct ColumnRange {
    leftmost: f64,
    rightmost: f64,
}

fn list_branch_heads(
    workflow: &Workflow,
    fork_id: WorkflowAgentId,
) -> Vec<WorkflowAgentId> {
    let mut heads = Vec::new();
    for connection in forward_connections(workflow) {
        let is_branch =
            connection.from == fork_id && connection.condition.is_some();
        if is_branch && !heads.contains(&connection.to) {
            heads.push(connection.to);
        }
    }
    heads
}

fn list_steps_only_in_each_branch(
    workflow: &Workflow,
    heads: &[WorkflowAgentId],
) -> Vec<BranchSteps> {
    let mut reached_per_branch = Vec::new();
    for head in heads {
        reached_per_branch.push(forward_reachable_agents(workflow, *head));
    }

    let mut steps_per_branch = Vec::new();
    for (position, reached) in reached_per_branch.iter().enumerate() {
        let mut only_in_branch = reached.clone();
        for (other_position, other) in reached_per_branch.iter().enumerate() {
            if other_position != position {
                only_in_branch.retain(|step| !other.contains(step));
            }
        }
        steps_per_branch.push(only_in_branch);
    }
    steps_per_branch
}

fn find_column_range(
    workflow: &Workflow,
    branch_steps: &BranchSteps,
) -> Option<ColumnRange> {
    let mut range: Option<ColumnRange> = None;
    for step_id in branch_steps {
        let Some(step) = find_agent_by_id(workflow, *step_id) else {
            continue;
        };
        let horizontal = step.position.horizontal;
        let widened = match range {
            Some(current) => ColumnRange {
                leftmost: current.leftmost.min(horizontal),
                rightmost: current.rightmost.max(horizontal),
            },
            None => ColumnRange {
                leftmost: horizontal,
                rightmost: horizontal,
            },
        };
        range = Some(widened);
    }
    range
}

fn list_branch_ranges_per_fork(workflow: &Workflow) -> Vec<Vec<ColumnRange>> {
    let mut ranges_per_fork = Vec::new();
    for fork in &workflow.agents {
        let heads = list_branch_heads(workflow, fork.id);
        let mut branch_ranges = Vec::new();
        for branch_steps in list_steps_only_in_each_branch(workflow, &heads) {
            if let Some(range) = find_column_range(workflow, &branch_steps) {
                branch_ranges.push(range);
            }
        }
        ranges_per_fork.push(branch_ranges);
    }
    ranges_per_fork
}

fn is_left_of(first: ColumnRange, second: ColumnRange) -> bool {
    first.rightmost + DRAWN_STEP_WIDTH <= second.leftmost
}

proptest! {
    #[test]
    fn test_lay_out_workflow_property_fork_branches_never_interleave(
        workflow in shuffled_fork_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        for branch_ranges in list_branch_ranges_per_fork(&laid_out) {
            for i in 0..branch_ranges.len() {
                for j in (i + 1)..branch_ranges.len() {
                    let first = branch_ranges[i];
                    let second = branch_ranges[j];
                    let are_apart =
                        is_left_of(first, second) || is_left_of(second, first);
                    prop_assert!(are_apart, "{first:?} and {second:?}");
                }
            }
        }
    }

    #[test]
    fn test_lay_out_workflow_property_fork_branches_follow_connection_order(
        workflow in shuffled_fork_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        for branch_ranges in list_branch_ranges_per_fork(&laid_out) {
            for neighbours in branch_ranges.windows(2) {
                let earlier = neighbours[0];
                let later = neighbours[1];
                prop_assert!(
                    is_left_of(earlier, later),
                    "{earlier:?} before {later:?}"
                );
            }
        }
    }
}
