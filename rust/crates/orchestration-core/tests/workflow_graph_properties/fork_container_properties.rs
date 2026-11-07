use orchestration_core::identifiers::WorkflowAgentId;
use orchestration_core::workflow::{AgentConnection, StepKind, Workflow};
use orchestration_core::workflow_layout::lay_out_workflow;
use proptest::prelude::*;

use crate::branching_strategies::shuffled_fork_workflow;
use crate::fork_reading::{
    are_lanes_apart, find_first_fork, find_root_join, is_lane_left_of,
    list_fork_ids, list_lane_steps_of_fork, list_steps_in_lanes,
    read_column_of,
};
use crate::layout_reading::{
    LaidOutRow, StepIds, drafted_workflow, find_span, is_same_coordinate,
    list_lanes, list_rows, read_column,
};
use crate::routing_fixtures::routing_agent;
use crate::workflow_strategies::workflow_from_parts;

const SIDES_OF_A_ROW: f64 = 2.0;

fn is_free_row(
    workflow: &Workflow,
    row: &LaidOutRow<'_>,
    lane_steps: &StepIds,
) -> bool {
    if row.iter().any(|agent| lane_steps.contains(&agent.id)) {
        return false;
    }
    let vertical = row[0].position.vertical;
    list_fork_ids(workflow).iter().all(|fork_id| {
        let fork_vertical = workflow
            .agents
            .iter()
            .find(|agent| agent.id == *fork_id)
            .map_or(vertical, |fork| fork.position.vertical);
        let deepest_lane_vertical =
            list_lane_steps_of_fork(workflow, *fork_id)
                .iter()
                .filter_map(|step_id| {
                    workflow.agents.iter().find(|agent| agent.id == *step_id)
                })
                .map(|step| step.position.vertical)
                .fold(f64::NEG_INFINITY, f64::max);
        vertical <= fork_vertical || vertical > deepest_lane_vertical
    })
}

fn find_row_centre(row: &LaidOutRow<'_>) -> f64 {
    let leftmost = read_column(row[0]);
    let rightmost = read_column(row[row.len() - 1]);
    (leftmost + rightmost) / SIDES_OF_A_ROW
}

fn extend_after(workflow: &Workflow, step_id: WorkflowAgentId) -> Workflow {
    let mut agent_count = 0;
    for _ in &workflow.agents {
        agent_count += 1;
    }
    let extension = routing_agent(agent_count, StepKind::Agent);
    let mut connections = workflow.connections.clone();
    connections.push(AgentConnection::plain(step_id, extension.id));
    let mut agents = workflow.agents.clone();
    agents.push(extension);
    workflow_from_parts(agents, connections)
}

fn is_inside_lanes_of(
    workflow: &Workflow,
    step_id: WorkflowAgentId,
    fork_id: WorkflowAgentId,
) -> bool {
    list_lane_steps_of_fork(workflow, fork_id).contains(&step_id)
}

proptest! {
    #[test]
    fn test_find_lane_of_each_step_property_outside_steps_stay_off_lanes(
        workflow in shuffled_fork_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        for fork_id in list_fork_ids(&laid_out) {
            let lane_steps = list_lane_steps_of_fork(&laid_out, fork_id);
            for row in &list_rows(&laid_out) {
                let lane_columns: Vec<f64> = row
                    .iter()
                    .filter(|agent| lane_steps.contains(&agent.id))
                    .map(|agent| read_column(agent))
                    .collect();
                let Some((leftmost, rightmost)) = find_span(&lane_columns)
                else {
                    continue;
                };
                for agent in row {
                    let column = read_column(agent);
                    let is_inside = column > leftmost && column < rightmost;
                    let is_outside_step = !lane_steps.contains(&agent.id);
                    prop_assert!(!(is_inside && is_outside_step));
                }
            }
        }
    }

    #[test]
    fn test_find_lane_of_each_step_property_laneless_steps_share_a_column(
        workflow in shuffled_fork_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        let lane_steps = list_steps_in_lanes(&laid_out);
        let laneless_columns: Vec<f64> = laid_out
            .agents
            .iter()
            .filter(|agent| !lane_steps.contains(&agent.id))
            .map(read_column)
            .collect();
        for neighbours in laneless_columns.windows(2) {
            prop_assert!(is_same_coordinate(neighbours[0], neighbours[1]));
        }
    }

    #[test]
    fn test_find_lane_of_each_step_property_forks_in_sibling_lanes_part(
        workflow in shuffled_fork_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        let fork_ids = list_fork_ids(&laid_out);
        for first in &fork_ids {
            for second in &fork_ids {
                let are_nested = first == second
                    || is_inside_lanes_of(&laid_out, *first, *second)
                    || is_inside_lanes_of(&laid_out, *second, *first);
                if are_nested {
                    continue;
                }
                let first_steps = list_lane_steps_of_fork(&laid_out, *first);
                let second_steps = list_lane_steps_of_fork(&laid_out, *second);
                let are_apart =
                    are_lanes_apart(&laid_out, &first_steps, &second_steps);
                prop_assert!(are_apart);
            }
        }
    }

    #[test]
    fn test_list_fork_last_rows_property_rows_past_every_group_are_centred(
        workflow in drafted_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        let lane_steps = list_steps_in_lanes(&laid_out);
        let free_rows: Vec<LaidOutRow<'_>> = list_rows(&laid_out)
            .into_iter()
            .filter(|row| is_free_row(&laid_out, row, &lane_steps))
            .collect();
        for row in &free_rows {
            for neighbours in row.windows(2) {
                let gap =
                    read_column(neighbours[1]) - read_column(neighbours[0]);
                prop_assert!(is_same_coordinate(gap, 1.0));
            }
        }
        for neighbours in free_rows.windows(2) {
            let first_centre = find_row_centre(&neighbours[0]);
            let second_centre = find_row_centre(&neighbours[1]);
            prop_assert!(is_same_coordinate(first_centre, second_centre));
        }
    }

    #[test]
    fn test_list_fork_last_rows_property_a_step_under_the_join_moves_nothing(
        workflow in shuffled_fork_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);
        let Some(root_fork_id) = find_first_fork(&laid_out) else {
            return Ok(());
        };
        let Some(join_id) = find_root_join(&laid_out, root_fork_id) else {
            return Ok(());
        };

        let extended = lay_out_workflow(&extend_after(&workflow, join_id));

        let agent_pairs = laid_out.agents.iter().zip(&extended.agents);
        for (agent, extended_agent) in agent_pairs {
            prop_assert_eq!(agent.position, extended_agent.position);
        }
        let extension_id = extended.agents[extended.agents.len() - 1].id;
        prop_assert_eq!(
            read_column_of(&extended, extension_id),
            read_column_of(&extended, join_id)
        );
    }

    #[test]
    fn test_list_fork_last_rows_property_lanes_keep_order_after_one_ends(
        workflow in shuffled_fork_workflow(),
    ) {
        let laid_out = lay_out_workflow(&workflow);

        for fork_id in list_fork_ids(&laid_out) {
            let lanes = list_lanes(&laid_out, fork_id);
            for i in 0..lanes.len() {
                for j in (i + 1)..lanes.len() {
                    let is_left =
                        is_lane_left_of(&laid_out, &lanes[i], &lanes[j]);
                    prop_assert!(is_left);
                }
            }
        }
    }

}
