#[allow(dead_code)]
#[path = "../business_rules/branching_strategies.rs"]
mod branching_strategies;
#[allow(dead_code)]
#[path = "../business_rules/entity_strategies.rs"]
mod entity_strategies;
#[allow(dead_code)]
#[path = "../business_rules/routing_fixtures.rs"]
mod routing_fixtures;
#[allow(dead_code)]
#[path = "../business_rules/run_fixtures.rs"]
mod run_fixtures;
#[allow(dead_code)]
#[path = "../business_rules/workflow_strategies.rs"]
mod workflow_strategies;

mod agent_wire_properties;
mod canvas_order_properties;
mod canvas_reading;
mod column_centring_properties;
mod column_order_properties;
mod column_tie_properties;
mod column_width_properties;
mod document_header_properties;
mod document_line_properties;
mod document_outcome_properties;
mod document_reading;
mod document_step_properties;
mod fork_container_properties;
mod fork_group_properties;
mod fork_lane_properties;
mod fork_nesting_properties;
mod fork_reading;
mod fork_row_properties;
mod graph_order_properties;
mod graph_query_properties;
mod graph_validation_properties;
mod layout_reading;
mod shared_graph_table_properties;
mod wire_reading;
mod workflow_model_properties;
mod workflow_problem_properties;
mod workflow_wire_properties;
