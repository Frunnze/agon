use orchestration_core::device::DeviceRole;

pub(crate) fn can_run_tasks(role: DeviceRole) -> bool {
    matches!(role, DeviceRole::Runner | DeviceRole::ClientAndRunner)
}

#[cfg(feature = "runner")]
pub(crate) fn can_decide_approvals(role: DeviceRole) -> bool {
    matches!(role, DeviceRole::Client | DeviceRole::ClientAndRunner)
}
