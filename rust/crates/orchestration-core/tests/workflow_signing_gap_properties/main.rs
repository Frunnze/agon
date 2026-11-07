#[allow(dead_code)]
#[path = "../business_rules/branching_strategies.rs"]
mod branching_strategies;
#[allow(dead_code)]
#[path = "../workflow_graph_properties/document_reading.rs"]
mod document_reading;
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

mod document_behaviour_properties;
mod document_connection_reading;
mod repeated_pair_properties;
mod signing_gap_support;
mod step_name_properties;
mod workflow_verdict_properties;
