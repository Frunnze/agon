#![allow(clippy::expect_used)]

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
#[path = "../server_properties/test_client.rs"]
mod test_client;

mod active_run_desk;
mod job_schedule_properties;
mod run_retry_properties;
mod run_start_properties;
mod second_run_refusal_properties;
