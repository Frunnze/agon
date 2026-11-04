use std::collections::BTreeMap;

use orchestration_api::server_group::ReplicaCopy;
use orchestration_core::identifiers::DeviceId;
use orchestration_core::server_group::ServerGroup;

#[derive(Debug, Default)]
pub struct ReplicaCopyLedger {
    latest_copy_requests: BTreeMap<DeviceId, ReplicaCopy>,
}

impl ReplicaCopyLedger {
    pub fn record(&mut self, copy_request: ReplicaCopy) {
        let device_id = copy_request.device_id.clone();
        self.latest_copy_requests.insert(device_id, copy_request);
    }

    pub fn copies_of_members(&self, group: &ServerGroup) -> Vec<ReplicaCopy> {
        let mut member_copies = Vec::new();
        for copy_request in self.latest_copy_requests.values() {
            let member = group.find_member_of_device(&copy_request.device_id);
            if member.is_some() {
                member_copies.push(copy_request.clone());
            }
        }
        member_copies
    }
}
