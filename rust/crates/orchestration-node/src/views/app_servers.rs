use chrono::{DateTime, Utc};
use orchestration_api::server_group::ServerGroupView;
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
pub struct CopyView {
    pub changes_behind: u64,
    pub verified_at: DateTime<Utc>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
pub struct AppServerView {
    pub device_id: DeviceId,
    pub standing: ServerStanding,
    pub copy: Option<CopyView>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
pub struct AppServersView {
    pub servers: Vec<AppServerView>,
    pub this_device: ThisDeviceStanding,
    pub can_keep_backup: bool,
}

#[must_use]
pub fn count_changes_behind(
    active_revision: u64,
    backup_revision: u64,
) -> u64 {
    active_revision.saturating_sub(backup_revision)
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
            copy: None,
        });
    }
    let can_host = cfg!(feature = "app-server");
    AppServersView {
        servers,
        this_device,
        can_keep_backup: can_host && own_device.role != DeviceRole::Runner,
    }
}

#[must_use]
pub fn describe_fresh_app_servers(
    fresh_view: &ServerGroupView,
    own_device: Option<&Device>,
) -> AppServersView {
    let view_without_copies =
        describe_app_servers(Some(&fresh_view.group), own_device);
    if fresh_view.standing == ServerStanding::Backup {
        return view_without_copies;
    }
    let mut servers = Vec::new();
    for server in view_without_copies.servers {
        let copy = describe_copy(fresh_view, &server);
        servers.push(AppServerView { copy, ..server });
    }
    AppServersView {
        servers,
        ..view_without_copies
    }
}

fn describe_copy(
    fresh_view: &ServerGroupView,
    server: &AppServerView,
) -> Option<CopyView> {
    if server.standing == ServerStanding::Active {
        return None;
    }
    let recorded_copy = fresh_view
        .copies
        .iter()
        .find(|copy| copy.device_id == server.device_id)?;
    let changes_behind = count_changes_behind(
        fresh_view.revision,
        recorded_copy.verified_revision,
    );
    Some(CopyView {
        changes_behind,
        verified_at: recorded_copy.verified_at,
    })
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
