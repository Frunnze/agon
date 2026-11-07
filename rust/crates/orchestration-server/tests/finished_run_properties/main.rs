#![allow(clippy::expect_used)]

#[allow(dead_code)]
#[path = "../server_properties/branching_fixtures.rs"]
mod branching_fixtures;
#[allow(dead_code)]
#[path = "../server_properties/claim_fixtures.rs"]
mod claim_fixtures;
#[allow(dead_code)]
#[path = "../server_properties/fixtures.rs"]
mod fixtures;
#[allow(dead_code)]
#[path = "../server_properties/library_fixtures.rs"]
mod library_fixtures;
#[allow(dead_code)]
#[path = "../server_properties/manual_clock.rs"]
mod manual_clock;
#[allow(dead_code)]
#[path = "../server_properties/pairing_fixtures.rs"]
mod pairing_fixtures;
#[allow(dead_code)]
#[path = "../server_properties/run_fixtures.rs"]
mod run_fixtures;
#[allow(dead_code)]
#[path = "../server_properties/skill_improvement_fixtures.rs"]
mod skill_improvement_fixtures;
#[allow(dead_code)]
#[path = "../server_properties/test_client.rs"]
mod test_client;
#[allow(dead_code)]
#[path = "../server_properties/workflow_fixtures.rs"]
mod workflow_fixtures;

mod approval_ending_support;
mod cancelled_run_properties;
mod failed_question_properties;
mod finished_approval_properties;
mod finished_run_support;
mod outliving_approval_properties;
mod question_guard_properties;
