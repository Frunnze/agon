use orchestration_core::device::{Device, DeviceRole};
use orchestration_core::identifiers::DeviceId;
use orchestration_core::server_group::{
    ServerGroup, ServerMember, ServerStanding,
};
use serde::Serialize;

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum ThisDeviceStanding {
    Active,
    Backup,
    None,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
pub struct AppServerView {
    pub device_id: DeviceId,
    pub standing: ServerStanding,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
pub struct AppServersView {
    pub servers: Vec<AppServerView>,
    pub this_device: ThisDeviceStanding,
    pub can_keep_backup: bool,
}

#[must_use]
pub fn describe_app_servers(
    group: Option<&ServerGroup>,
    own_device: Option<&Device>,
) -> AppServersView {
    let founded_group = group.filter(|group| group.term.is_some());
    let (Some(group), Some(own_device)) = (founded_group, own_device) else {
        return AppServersView {
            servers: Vec::new(),
            this_device: ThisDeviceStanding::None,
            can_keep_backup: false,
        };
    };
    let mut servers = Vec::new();
    let mut this_device = ThisDeviceStanding::None;
    for member in group.members_active_first() {
        let standing = describe_standing(group, member);
        let device_id = member.membership.device_id.clone();
        if device_id == own_device.id {
            this_device = match standing {
                ServerStanding::Active => ThisDeviceStanding::Active,
                ServerStanding::Backup => ThisDeviceStanding::Backup,
            };
        }
        servers.push(AppServerView {
            device_id,
            standing,
        });
    }
    let can_host = cfg!(feature = "app-server");
    AppServersView {
        servers,
        this_device,
        can_keep_backup: can_host && own_device.role != DeviceRole::Runner,
    }
}

fn describe_standing(
    group: &ServerGroup,
    member: &ServerMember,
) -> ServerStanding {
    if group.active_server_id() == Some(&member.membership.server_id) {
        return ServerStanding::Active;
    }
    ServerStanding::Backup
}
