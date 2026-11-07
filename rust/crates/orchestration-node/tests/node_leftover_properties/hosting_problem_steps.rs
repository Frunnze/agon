use std::fs;
use std::net::{Ipv4Addr, TcpListener};
use std::thread;

use orchestration_node::node_runtime::NodeRuntime;
use proptest::prelude::*;
use serde_json::{Value, json};
use tempfile::TempDir;

use crate::runtime_steps::{
    host_on, hosted_directory_in, hosted_record_in, run_on, start_runtime,
};
use crate::support::hosting_steps::pick_free_port;
use crate::support::test_device::describe;

const DAMAGED_TEXT_PATTERN: &str = "\\PC{0,40}";
const MOST_DAMAGED_BYTES: usize = 64;
const PORT_FIELD: &str = "port";
const GROUP_FILE_NAME: &str = "server-group.json";

#[derive(Clone, Debug)]
pub enum HostingFailure {
    TakenPort,
    DamagedRecord(Vec<u8>),
}

#[derive(Debug)]
pub struct HostedData {
    pub data_directory: TempDir,
    pub port: u16,
}

#[derive(Debug)]
pub struct FailedHosting {
    pub hosted: HostedData,
    pub runtime: NodeRuntime,
    pub occupier: Option<TcpListener>,
}

pub fn prepare_hosted_data() -> Result<HostedData, String> {
    let data_directory = TempDir::new().map_err(describe)?;
    let port = pick_free_port()?;
    let runtime = start_runtime(data_directory.path(), port)?;
    host_on(&runtime)?;
    drop(runtime);
    Ok(HostedData {
        data_directory,
        port,
    })
}

pub fn start_after_failure(
    failure: &HostingFailure,
) -> Result<FailedHosting, String> {
    let hosted = prepare_hosted_data()?;
    let group_path = hosted.data_directory.path().join(GROUP_FILE_NAME);
    fs::remove_file(group_path).map_err(describe)?;
    let occupier = match failure {
        HostingFailure::TakenPort => Some(occupy_port(hosted.port)?),
        HostingFailure::DamagedRecord(damaged_bytes) => {
            let record_path = hosted_record_in(hosted.data_directory.path());
            fs::write(record_path, damaged_bytes).map_err(describe)?;
            None
        }
    };
    let runtime = start_runtime(hosted.data_directory.path(), hosted.port)?;
    Ok(FailedHosting {
        hosted,
        runtime,
        occupier,
    })
}

fn occupy_port(port: u16) -> Result<TcpListener, String> {
    let listener =
        TcpListener::bind((Ipv4Addr::LOCALHOST, port)).map_err(describe)?;
    let accepting = listener.try_clone().map_err(describe)?;
    thread::spawn(move || drop_every_connection(&accepting));
    Ok(listener)
}

fn drop_every_connection(listener: &TcpListener) {
    for connection in listener.incoming() {
        drop(connection);
    }
}

pub fn read_status_on(runtime: &NodeRuntime) -> Result<Value, String> {
    run_on(runtime, &json!({ "command": "status" }))
}

pub fn forget_device_on(runtime: &NodeRuntime) -> Result<Value, String> {
    run_on(runtime, &json!({ "command": "forget_this_device" }))
}

pub fn has_hosted_files(hosted: &HostedData) -> bool {
    let data_directory = hosted.data_directory.path();
    hosted_record_in(data_directory).exists()
        || hosted_directory_in(data_directory).exists()
}

pub fn hosting_failure_strategy() -> impl Strategy<Value = HostingFailure> {
    prop_oneof![
        Just(HostingFailure::TakenPort),
        damaged_record_strategy().prop_map(HostingFailure::DamagedRecord),
    ]
}

pub fn damaged_record_strategy() -> impl Strategy<Value = Vec<u8>> {
    let damaged_text = DAMAGED_TEXT_PATTERN.prop_map(String::into_bytes);
    let damaged_bytes =
        prop::collection::vec(any::<u8>(), 0..MOST_DAMAGED_BYTES);
    prop_oneof![damaged_text, damaged_bytes]
        .prop_filter("not a hosted server record", |bytes| {
            !may_hold_a_port(bytes)
        })
}

fn may_hold_a_port(bytes: &[u8]) -> bool {
    let parsed: Result<Value, _> = serde_json::from_slice(bytes);
    let Ok(record) = parsed else {
        return false;
    };
    record.is_array() || record.get(PORT_FIELD).is_some()
}
