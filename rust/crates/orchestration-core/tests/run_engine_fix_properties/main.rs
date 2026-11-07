#[allow(dead_code)]
#[path = "../business_rules/entity_strategies.rs"]
mod entity_strategies;
#[allow(dead_code)]
#[path = "../core_rules_properties/loop_support.rs"]
mod loop_support;
#[allow(dead_code)]
#[path = "../business_rules/routing_fixtures.rs"]
mod routing_fixtures;
#[allow(dead_code)]
#[path = "../business_rules/run_fixtures.rs"]
mod run_fixtures;
#[allow(dead_code)]
#[path = "../business_rules/workflow_strategies.rs"]
mod workflow_strategies;

mod failure_skip_properties;
mod finished_loop_properties;
mod nested_loop_properties;
mod nested_loop_support;
mod nested_round_count_properties;
mod run_stop_properties;
mod skipped_step_support;
