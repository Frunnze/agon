use std::time::Duration;

use orchestration_core::peer_address::PeerAddress;
use serde_json::{Value, json};

use super::two_nodes::TwoNodes;
use super::waiting::wait_for;

const ADDRESS_LIMIT: Duration = Duration::from_secs(30);

pub fn wait_for_runner_address(nodes: &TwoNodes) -> PeerAddress {
    let published =
        wait_for(ADDRESS_LIMIT, "the runner's peer address", || {
            let devices =
                nodes.client.run(&json!({ "command": "list_devices" }))?;
            Ok(find_runner_address(&devices))
        });
    let Ok(address) = published else {
        panic!("the runner publishes an address: {published:?}");
    };
    address
}

fn find_runner_address(devices: &Value) -> Option<PeerAddress> {
    let runner = devices
        .as_array()?
        .iter()
        .find(|device| device["is_this_device"] == false)?;
    let address = runner["device"]["peer_address"]["address"].clone();
    serde_json::from_value(address).ok()
}
