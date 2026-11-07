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

mod agent_kind_label_properties;
mod agent_place_properties;
mod agents_markdown_properties;
mod approval_properties;
mod condition_properties;
mod document_diff_properties;
mod identifier_properties;
mod local_address_properties;
mod local_folder_root_properties;
mod loop_reset_properties;
mod loop_round_properties;
mod loop_support;
mod naming_properties;
mod path_matching_properties;
mod path_resolution_properties;
mod path_segment_properties;
mod protected_path_support;
mod protected_pattern_properties;
mod workflow_loop_properties;
