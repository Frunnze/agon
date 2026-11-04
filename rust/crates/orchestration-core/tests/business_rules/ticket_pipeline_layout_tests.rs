use orchestration_core::workflow::{
    AgentConnection, CanvasPosition, Workflow,
};
use orchestration_core::workflow_graph::{
    find_agent_by_id, validate_workflow,
};
use orchestration_core::workflow_layout::lay_out_workflow;

use crate::routing_fixtures::{connect, routing_workflow};
use crate::workflow_strategies::agent_identifier;

const TICKET_PIPELINE_STEP_COUNT: u128 = 21;
const DRAWN_STEP_WIDTH: f64 = 160.0;
const DRAWN_STEP_HEIGHT: f64 = 88.0;
const PICK_TICKET: u128 = 0;
const READ_TICKET: u128 = 1;
const RESEARCH_STEPS: [u128; 5] = [2, 3, 4, 5, 6];
const PLAN: u128 = 7;
const APPROVE_PLAN: u128 = 8;
const ROUTE: u128 = 9;
const CODE_REVIEW_LANE: [u128; 2] = [10, 11];
const RETURNED_LANE: [u128; 3] = [12, 13, 14];
const BUILD_LANE: [u128; 4] = [15, 16, 17, 18];
const LANE_STARTS: [u128; 3] =
    [CODE_REVIEW_LANE[0], RETURNED_LANE[0], BUILD_LANE[0]];
const ROUND_LIMIT: u32 = 3;
const OPEN_PULL_REQUEST: u128 = 19;
const REPORT: u128 = 20;
const SPINE_HORIZONTAL: f64 = 416.0;
const RESEARCH_HORIZONTALS: [f64; 5] = [0.0, 208.0, 416.0, 624.0, 832.0];
const RESEARCH_VERTICAL: f64 = 304.0;
const LANE_HORIZONTALS: [f64; 3] = [208.0, 416.0, 624.0];
const LANE_VERTICAL: f64 = 912.0;

fn connect_always(from: u128, to: u128) -> AgentConnection {
    connect(from, to, None, None)
}

fn connect_on(from: u128, to: u128, outcome: &str) -> AgentConnection {
    connect(from, to, Some(outcome), None)
}

fn loop_back(from: u128, to: u128, outcome: &str) -> AgentConnection {
    connect(from, to, Some(outcome), Some(ROUND_LIMIT))
}

fn chain_lane(lane: &[u128], outcome: &str) -> Vec<AgentConnection> {
    let mut connections = vec![connect_on(ROUTE, lane[0], outcome)];
    for neighbours in lane.windows(2) {
        connections.push(connect_always(neighbours[0], neighbours[1]));
    }
    let lane_end = lane[lane.len() - 1];
    connections.push(connect_always(lane_end, OPEN_PULL_REQUEST));
    connections
}

fn ticket_pipeline_workflow() -> Workflow {
    let mut connections = vec![connect_always(PICK_TICKET, READ_TICKET)];
    for research_step in RESEARCH_STEPS {
        connections.push(connect_always(READ_TICKET, research_step));
        connections.push(connect_always(research_step, PLAN));
    }
    connections.extend([
        connect_always(PLAN, APPROVE_PLAN),
        loop_back(APPROVE_PLAN, PLAN, "changes"),
        connect_on(APPROVE_PLAN, ROUTE, "approved"),
    ]);
    connections.extend(chain_lane(&CODE_REVIEW_LANE, "code review"));
    connections.extend(chain_lane(&RETURNED_LANE, "returned"));
    connections.extend(chain_lane(&BUILD_LANE, "build"));
    connections.extend([
        loop_back(RETURNED_LANE[1], RETURNED_LANE[0], "unresolved"),
        loop_back(BUILD_LANE[3], BUILD_LANE[1], "findings"),
        connect_always(OPEN_PULL_REQUEST, REPORT),
        loop_back(REPORT, ROUTE, "again"),
    ]);
    routing_workflow(TICKET_PIPELINE_STEP_COUNT, connections)
}

fn find_position(workflow: &Workflow, number: u128) -> CanvasPosition {
    let agent = find_agent_by_id(workflow, agent_identifier(number));
    let Some(agent) = agent else {
        panic!("step {number} is in the workflow");
    };
    agent.position
}

fn find_lane_columns(workflow: &Workflow, lane: &[u128]) -> (f64, f64) {
    let mut leftmost = f64::INFINITY;
    let mut rightmost = f64::NEG_INFINITY;
    for step in lane {
        let horizontal = find_position(workflow, *step).horizontal;
        leftmost = leftmost.min(horizontal);
        rightmost = rightmost.max(horizontal);
    }
    (leftmost, rightmost)
}

fn do_steps_overlap(first: CanvasPosition, second: CanvasPosition) -> bool {
    let horizontal_distance = (first.horizontal - second.horizontal).abs();
    let vertical_distance = (first.vertical - second.vertical).abs();
    horizontal_distance < DRAWN_STEP_WIDTH
        && vertical_distance < DRAWN_STEP_HEIGHT
}

#[test]
fn a_ticket_pipeline_workflow_is_valid_and_drafted_stacked() {
    let workflow = ticket_pipeline_workflow();

    assert_eq!(validate_workflow(&workflow), Ok(()));
    let first = workflow.agents[0].position;
    assert!(do_steps_overlap(first, workflow.agents[1].position));
}

#[test]
fn a_ticket_pipeline_workflow_is_laid_out_without_overlaps() {
    let laid_out = lay_out_workflow(&ticket_pipeline_workflow());

    let agents = &laid_out.agents;
    for i in 0..agents.len() {
        for j in (i + 1)..agents.len() {
            let first = agents[i].position;
            let second = agents[j].position;
            assert!(!do_steps_overlap(first, second), "{i} and {j}");
        }
    }
}

#[test]
fn the_five_research_steps_sit_side_by_side_in_one_row() {
    let laid_out = lay_out_workflow(&ticket_pipeline_workflow());

    for (research_step, expected_horizontal) in
        RESEARCH_STEPS.into_iter().zip(RESEARCH_HORIZONTALS)
    {
        let expected = CanvasPosition {
            horizontal: expected_horizontal,
            vertical: RESEARCH_VERTICAL,
        };
        assert_eq!(find_position(&laid_out, research_step), expected);
    }
}

#[test]
fn the_three_lanes_start_side_by_side_under_the_fork() {
    let laid_out = lay_out_workflow(&ticket_pipeline_workflow());

    for (lane_start, expected_horizontal) in
        LANE_STARTS.into_iter().zip(LANE_HORIZONTALS)
    {
        let expected = CanvasPosition {
            horizontal: expected_horizontal,
            vertical: LANE_VERTICAL,
        };
        assert_eq!(find_position(&laid_out, lane_start), expected);
    }
}

#[test]
fn each_lane_keeps_to_its_own_columns_in_the_fork_order() {
    let laid_out = lay_out_workflow(&ticket_pipeline_workflow());

    let lanes: [&[u128]; 3] = [&CODE_REVIEW_LANE, &RETURNED_LANE, &BUILD_LANE];
    for neighbours in lanes.windows(2) {
        let (_, left_lane_rightmost) =
            find_lane_columns(&laid_out, neighbours[0]);
        let (right_lane_leftmost, _) =
            find_lane_columns(&laid_out, neighbours[1]);
        let left_lane_right_edge = left_lane_rightmost + DRAWN_STEP_WIDTH;
        assert!(
            left_lane_right_edge <= right_lane_leftmost,
            "{neighbours:?}"
        );
    }
}

#[test]
fn the_single_steps_line_up_on_the_shared_middle() {
    let laid_out = lay_out_workflow(&ticket_pipeline_workflow());

    for spine_step in [PICK_TICKET, PLAN, ROUTE, OPEN_PULL_REQUEST, REPORT] {
        let position = find_position(&laid_out, spine_step);
        assert_eq!(position.horizontal, SPINE_HORIZONTAL, "{spine_step}");
    }
}

#[test]
fn the_loops_back_leave_the_rows_in_forward_order() {
    let laid_out = lay_out_workflow(&ticket_pipeline_workflow());

    let route_row = find_position(&laid_out, ROUTE).vertical;
    let report_row = find_position(&laid_out, REPORT).vertical;
    let plan_row = find_position(&laid_out, PLAN).vertical;
    let approval_row = find_position(&laid_out, APPROVE_PLAN).vertical;
    assert!(route_row < report_row);
    assert!(plan_row < approval_row);
}
