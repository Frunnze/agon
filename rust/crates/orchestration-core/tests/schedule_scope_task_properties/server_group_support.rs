use chrono::{DateTime, TimeDelta, Utc};
use orchestration_core::identifiers::DeviceId;
use orchestration_core::peer_address::{
    ENDPOINT_PUBLIC_KEY_LENGTH, PeerAddress,
};
use orchestration_core::server_group::{
    AuditSigners, ServerGroup, ServerMember, ServerMembership, ServerTerm,
};
use proptest::collection::vec;
use proptest::prelude::*;

pub const SERVER_NAMES: [&str; 5] = ["a", "b", "c", "d", "e"];
pub const MOST_TERM_NUMBER: u64 = 6;
pub const MOST_JOIN_SECOND: i64 = 4;
pub const STRANGER_NAME: &str = "stranger";
const DEVICE_PREFIX: &str = "device-";

pub type JoinPlan = Vec<(&'static str, i64)>;

pub fn server(name: &str) -> DeviceId {
    DeviceId(name.to_owned())
}

pub fn device_of(server_name: &str) -> DeviceId {
    DeviceId(format!("{DEVICE_PREFIX}{server_name}"))
}

pub fn term(number: u64, server_name: &str) -> ServerTerm {
    ServerTerm {
        number,
        server_id: server(server_name),
        claimed_by: device_of(server_name),
        signature: Vec::new(),
    }
}

pub fn joined_at(joined_second: i64) -> DateTime<Utc> {
    DateTime::<Utc>::UNIX_EPOCH + TimeDelta::seconds(joined_second)
}

pub fn member_for(server_name: &str, joined_second: i64) -> ServerMember {
    let endpoint_public_key = [0; ENDPOINT_PUBLIC_KEY_LENGTH];
    ServerMember {
        membership: ServerMembership {
            device_id: device_of(server_name),
            server_id: server(server_name),
            server_signing_public_key: Vec::new(),
            endpoint_public_key,
            joined_at: joined_at(joined_second),
            signature: Vec::new(),
        },
        address: PeerAddress {
            endpoint_public_key,
            direct_addresses: Vec::new(),
            relay_url: None,
        },
    }
}

pub fn group_of(
    term: Option<ServerTerm>,
    members: Vec<ServerMember>,
) -> ServerGroup {
    ServerGroup {
        term,
        members,
        audit_signers: AuditSigners::new(),
    }
}

pub fn join_plan() -> impl Strategy<Value = JoinPlan> {
    let names = prop::sample::subsequence(
        SERVER_NAMES.to_vec(),
        1..=SERVER_NAMES.len(),
    )
    .prop_shuffle();
    names
        .prop_flat_map(|names| {
            let count = names.len();
            (Just(names), vec(0..MOST_JOIN_SECOND, count))
        })
        .prop_map(|(names, seconds)| names.into_iter().zip(seconds).collect())
}

pub fn members_of(plan: &JoinPlan) -> Vec<ServerMember> {
    let mut members: Vec<ServerMember> = Vec::new();
    for (name, joined_second) in plan {
        members.push(member_for(name, *joined_second));
    }
    members
}

pub fn kept_group() -> impl Strategy<Value = ServerGroup> {
    (
        join_plan(),
        any::<prop::sample::Index>(),
        1..MOST_TERM_NUMBER,
    )
        .prop_map(|(plan, active_index, number)| {
            let (active_name, _) = *active_index.get(&plan);
            let active_term = term(number, active_name);
            group_of(Some(active_term), members_of(&plan))
        })
}

pub fn any_group() -> impl Strategy<Value = ServerGroup> {
    let any_term = proptest::option::of(
        (
            0..MOST_TERM_NUMBER,
            prop::sample::select(SERVER_NAMES.to_vec()),
        )
            .prop_map(|(number, name)| term(number, name)),
    );
    (any_term, proptest::option::of(join_plan())).prop_map(
        |(chosen_term, plan)| {
            let members = plan.map(|plan| members_of(&plan));
            group_of(chosen_term, members.unwrap_or_default())
        },
    )
}

pub fn join_key(member: &ServerMember) -> (DateTime<Utc>, DeviceId) {
    (
        member.membership.joined_at,
        member.membership.server_id.clone(),
    )
}

pub fn server_ids(members: &[&ServerMember]) -> Vec<DeviceId> {
    let mut ids: Vec<DeviceId> = Vec::new();
    for member in members {
        ids.push(member.membership.server_id.clone());
    }
    ids
}

pub fn reversed_members(group: &ServerGroup) -> ServerGroup {
    let mut members = group.members.clone();
    members.reverse();
    ServerGroup {
        members,
        ..group.clone()
    }
}
