#[allow(dead_code)]
#[path = "../node/support/mod.rs"]
mod support;

#[allow(dead_code)]
#[path = "../rendezvous_pairing_properties/approver_desk.rs"]
mod approver_desk;
#[allow(dead_code)]
#[path = "../rendezvous_pairing_properties/at_once.rs"]
mod at_once;
#[allow(dead_code)]
#[path = "../rendezvous_pairing_properties/command_device.rs"]
mod command_device;
#[allow(dead_code)]
#[path = "../rendezvous_pairing_properties/meddling_server.rs"]
mod meddling_server;
#[allow(dead_code)]
#[path = "../reply_and_host_properties/rendezvous_records.rs"]
mod rendezvous_records;
#[allow(dead_code)]
#[path = "../server_hosting_backup_properties/runtime_steps.rs"]
mod runtime_steps;

mod approver_expiry_properties;
mod hosting_problem_access_properties;
mod hosting_problem_properties;
mod hosting_problem_steps;
mod pending_join_properties;
mod problem_clearing_properties;
mod record_rule_properties;
mod refused_cancel_properties;
mod rendezvous_ending_properties;
mod short_session_server;
mod silent_board_limit_properties;
mod slow_board;
mod slow_board_properties;
mod unit_command_checks;
mod unit_command_properties;
