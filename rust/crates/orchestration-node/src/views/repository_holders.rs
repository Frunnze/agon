use chrono::{DateTime, Utc};
use orchestration_core::device::{Device, Runner};
use orchestration_core::identifiers::DeviceId;
use serde::Serialize;

#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
pub struct RepositoryHolder {
    pub device_id: DeviceId,
    pub name: String,
    pub last_seen: DateTime<Utc>,
    #[serde(skip)]
    pub online: bool,
}

#[must_use]
pub fn find_repository_holders(
    runners: &[Runner],
    devices: &[Device],
    address: &str,
) -> Vec<RepositoryHolder> {
    let mut holders = Vec::new();
    for runner in runners {
        let holds_copy = runner
            .cached_repositories
            .iter()
            .any(|cached| cached == address);
        let device = devices
            .iter()
            .find(|device| device.id == runner.device_id && !device.revoked);
        if let (true, Some(device)) = (holds_copy, device) {
            holders.push(RepositoryHolder {
                device_id: device.id.clone(),
                name: device.name.clone(),
                last_seen: device.last_seen,
                online: runner.online,
            });
        }
    }
    holders.sort_by(|first, second| {
        second
            .last_seen
            .cmp(&first.last_seen)
            .then_with(|| first.device_id.0.cmp(&second.device_id.0))
    });
    holders
}
