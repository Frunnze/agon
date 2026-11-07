use std::fs;
use std::thread;
use std::time::Duration;

use orchestration_node::server_address::ServerAddress;
use serde_json::{Value, json};

use crate::support::hosted_runner::{
    HostedRunner, PLAN_DETAILS, WORKTREES_FOLDER_NAME, join_and_approve,
    run_a_task_to_done, start_host_pairing, start_runner_beside_host,
};
use crate::support::hosting_steps::PEER_SCHEME_PREFIX;
use crate::support::public_board_turn::wait_for_public_board_turn;
use crate::support::rendezvous_lookup::look_up_code;
use crate::support::test_device::{RELAY_DEFAULT, RELAY_DISABLED, read_text};

const PLAN_PROMPT_RECORD: &str = "plan-prompt.txt";
const RECORD_ATTEMPTS: u32 = 30;
const RECORD_ATTEMPT_PAUSE: Duration = Duration::from_secs(1);

fn start_or_panic(peer_relay: &str) -> HostedRunner {
    match start_runner_beside_host(peer_relay) {
        Ok(nodes) => nodes,
        Err(problem) => panic!("the host and the runner start: {problem}"),
    }
}

fn look_up_until_published(code: &str) -> Result<ServerAddress, String> {
    let mut last_problem = String::new();
    for _attempt in 0..RECORD_ATTEMPTS {
        match look_up_code(code) {
            Ok(address) => return Ok(address),
            Err(problem) => last_problem = problem,
        }
        thread::sleep(RECORD_ATTEMPT_PAUSE);
    }
    Err(last_problem)
}

fn read_runner_server_address(nodes: &HostedRunner) -> Result<String, String> {
    let status = nodes.runner.run(&json!({ "command": "status" }))?;
    read_text(&status, "/server_address")
}

fn assert_task_ran_over_the_peer_link(nodes: HostedRunner) {
    let runner_address = read_runner_server_address(&nodes);
    let finished = run_a_task_to_done(&nodes);

    let Ok(runner_address) = runner_address else {
        panic!("the runner names its app server: {runner_address:?}");
    };
    assert!(
        runner_address.starts_with(PEER_SCHEME_PREFIX),
        "{runner_address}"
    );
    let Ok(finished) = finished else {
        panic!("the task runs to done: {finished:?}");
    };
    assert_eq!(finished["run"]["status"], "done");
    let prompt_path = nodes.records.path().join(PLAN_PROMPT_RECORD);
    let prompt = fs::read_to_string(prompt_path).unwrap_or_default();
    assert!(prompt.contains(PLAN_DETAILS), "{prompt}");
    let worktrees = nodes.runner_data.path().join(WORKTREES_FOLDER_NAME);
    assert!(worktrees.is_dir());
    let HostedRunner { runner, .. } = nodes;
    assert_eq!(runner.stop(), Ok(true));
}

#[test]
fn a_local_runner_pairs_with_the_code_and_works_over_the_peer_link() {
    let nodes = start_or_panic(RELAY_DISABLED);
    let Ok(session) = start_host_pairing(&nodes) else {
        panic!("pairing starts");
    };

    let paired = join_and_approve(&nodes, &session, None);

    assert_eq!(paired, Ok(()));
    assert_task_ran_over_the_peer_link(nodes);
}

#[test]
fn a_runner_with_only_the_published_record_works_over_the_peer_link() {
    let _board_turn = wait_for_public_board_turn();

    let nodes = start_or_panic(RELAY_DEFAULT);
    let Ok(session) = start_host_pairing(&nodes) else {
        panic!("pairing starts");
    };
    let Ok(code) = read_text(&session, "/display_code") else {
        panic!("the session shows a code");
    };
    let board_problem = session.get("rendezvous_problem");
    assert_eq!(board_problem, Some(&Value::Null), "the public board");

    let published = look_up_until_published(&code);
    let Ok(ServerAddress::Peer(peer_address)) = published else {
        panic!("the record names a peer address: {published:?}");
    };
    let published_text = ServerAddress::Peer(peer_address).to_string();
    let paired = join_and_approve(&nodes, &session, Some(published_text));

    assert_eq!(paired, Ok(()));
    assert_task_ran_over_the_peer_link(nodes);
}
