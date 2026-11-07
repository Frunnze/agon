#![allow(clippy::expect_used)]

#[allow(dead_code)]
#[path = "../../../orchestration-core/tests/repository_and_run_properties/address_strategies.rs"]
mod address_strategies;
#[allow(dead_code)]
#[path = "../server_properties/fixtures.rs"]
mod fixtures;
#[allow(dead_code)]
#[path = "../server_properties/manual_clock.rs"]
mod manual_clock;
#[allow(dead_code)]
#[path = "../server_properties/pairing_fixtures.rs"]
mod pairing_fixtures;
#[allow(dead_code)]
#[path = "../server_properties/server_group_fixtures.rs"]
mod server_group_fixtures;
#[allow(dead_code)]
#[path = "../server_properties/test_client.rs"]
mod test_client;

mod old_stored_addresses;
mod stored_address_clone_properties;
mod stored_project_listing_properties;
mod stored_replica_properties;
mod stored_repository_removal_properties;
mod stored_state_loading_properties;
