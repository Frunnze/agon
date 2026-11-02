use std::collections::BTreeMap;

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

use crate::identifiers::DeviceId;
use crate::peer_address::{ENDPOINT_PUBLIC_KEY_LENGTH, PeerAddress};

pub type AuditSigners = BTreeMap<DeviceId, Vec<u8>>;

const FIRST_TAKEOVER_POSITION: usize = 1;

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ServerStanding {
    Active,
    Backup,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ServerMembership {
    pub device_id: DeviceId,
    pub server_id: DeviceId,
    pub server_signing_public_key: Vec<u8>,
    pub endpoint_public_key: [u8; ENDPOINT_PUBLIC_KEY_LENGTH],
    pub joined_at: DateTime<Utc>,
    pub signature: Vec<u8>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ServerMember {
    pub membership: ServerMembership,
    pub address: PeerAddress,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ServerTerm {
    pub number: u64,
    pub server_id: DeviceId,
    pub claimed_by: DeviceId,
    pub signature: Vec<u8>,
}

#[derive(Clone, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct ServerGroup {
    pub term: Option<ServerTerm>,
    pub members: Vec<ServerMember>,
    pub audit_signers: AuditSigners,
}

impl ServerMember {
    #[must_use]
    pub fn has_signed_address(&self) -> bool {
        self.address.endpoint_public_key == self.membership.endpoint_public_key
    }
}

impl ServerTerm {
    #[must_use]
    pub fn outranks(&self, other: &Self) -> bool {
        (self.number, &self.server_id) > (other.number, &other.server_id)
    }
}

impl ServerGroup {
    #[must_use]
    pub fn active_server_id(&self) -> Option<&DeviceId> {
        self.term.as_ref().map(|term| &term.server_id)
    }

    #[must_use]
    pub fn has_backups(&self) -> bool {
        self.members.len() > 1
    }

    #[must_use]
    pub fn find_member(&self, server_id: &DeviceId) -> Option<&ServerMember> {
        self.members
            .iter()
            .find(|member| &member.membership.server_id == server_id)
    }

    #[must_use]
    pub fn find_member_of_device(
        &self,
        device_id: &DeviceId,
    ) -> Option<&ServerMember> {
        self.members
            .iter()
            .find(|member| &member.membership.device_id == device_id)
    }

    #[must_use]
    pub fn backups_in_order(&self) -> Vec<&ServerMember> {
        self.backups_behind(self.active_server_id())
    }

    #[must_use]
    pub fn members_active_first(&self) -> Vec<&ServerMember> {
        let active_member = self
            .active_server_id()
            .and_then(|server_id| self.find_member(server_id));
        let mut members: Vec<&ServerMember> =
            active_member.into_iter().collect();
        members.extend(self.backups_in_order());
        members
    }

    #[must_use]
    pub fn takeover_position(
        &self,
        server_id: &DeviceId,
        active_server_id: &DeviceId,
    ) -> Option<usize> {
        let backups = self.backups_behind(Some(active_server_id));
        let index = backups
            .iter()
            .position(|member| &member.membership.server_id == server_id)?;
        Some(index + FIRST_TAKEOVER_POSITION)
    }

    fn backups_behind(
        &self,
        active_server_id: Option<&DeviceId>,
    ) -> Vec<&ServerMember> {
        let mut backups: Vec<&ServerMember> = Vec::new();
        for member in &self.members {
            if Some(&member.membership.server_id) != active_server_id {
                backups.push(member);
            }
        }
        backups.sort_by(|first, second| {
            let first_key =
                (first.membership.joined_at, &first.membership.server_id);
            let second_key =
                (second.membership.joined_at, &second.membership.server_id);
            first_key.cmp(&second_key)
        });
        backups
    }
}
