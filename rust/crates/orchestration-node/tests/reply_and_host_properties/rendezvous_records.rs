use std::net::SocketAddr;

use chrono::{DateTime, TimeDelta, Utc};
use orchestration_core::peer_address::PeerAddress;
use orchestration_node::code_rendezvous::{
    MAXIMUM_RECORDED_DIRECT_ADDRESSES, decode_rendezvous_record,
    encode_rendezvous_record,
};
use orchestration_node::server_address::ServerAddress;
use proptest::prelude::*;

use crate::support::address_strategies::{
    direct_address_strategy, peer_address_strategy, server_address_strategy,
};

pub const EXPIRY_PREFIX: &str = "expires=";
pub const SERVER_PREFIX: &str = "server=";
pub const DIRECT_PREFIX: &str = "direct=";
pub const MALFORMED_PREFIX: &str =
    "the published record for the code is malformed: ";
pub const NO_SERVER_ACCEPTED_CODE: &str = "no app server accepted the code";
pub const CROWDED_ADDRESS_LIMIT: usize = 3 * MAXIMUM_RECORDED_DIRECT_ADDRESSES;
const EARLIEST_SECONDS: i64 = 1_700_000_000;
const LATEST_SECONDS: i64 = 2_000_000_000;
const NANOSECONDS_PER_SECOND: u32 = 1_000_000_000;
const LIFETIME_SECONDS: i64 = 300;

pub type RecordFields = Vec<String>;

#[derive(Clone, Debug)]
pub struct LiveRecord {
    pub server: ServerAddress,
    pub now: DateTime<Utc>,
    pub expires_at: DateTime<Utc>,
    pub fields: RecordFields,
}

pub fn moment_strategy() -> impl Strategy<Value = DateTime<Utc>> {
    (EARLIEST_SECONDS..LATEST_SECONDS, 0..NANOSECONDS_PER_SECOND)
        .prop_map(build_moment)
}

pub fn crowded_peer_strategy() -> impl Strategy<Value = PeerAddress> {
    let direct_addresses = prop::collection::vec(
        direct_address_strategy(),
        0..CROWDED_ADDRESS_LIMIT,
    );
    (peer_address_strategy(), direct_addresses).prop_map(crowd_peer)
}

pub fn recordable_server_strategy() -> impl Strategy<Value = ServerAddress> {
    let any_server = prop_oneof![
        server_address_strategy(),
        crowded_peer_strategy().prop_map(ServerAddress::Peer),
    ];
    any_server
        .prop_filter_map("the server parses", |server| reparse_server(&server))
}

pub fn live_record_strategy() -> impl Strategy<Value = LiveRecord> {
    let seconds_left = 1..LIFETIME_SECONDS;
    (
        recordable_server_strategy(),
        moment_strategy(),
        seconds_left,
    )
        .prop_map(build_live_record)
}

pub fn shuffled_live_record_strategy()
-> impl Strategy<Value = (LiveRecord, RecordFields)> {
    live_record_strategy().prop_flat_map(shuffle_record_fields)
}

pub fn recorded_direct_addresses(server: &ServerAddress) -> Vec<SocketAddr> {
    let mut recorded = Vec::new();
    let kept = server
        .direct_addresses()
        .iter()
        .take(MAXIMUM_RECORDED_DIRECT_ADDRESSES);
    for direct_address in kept {
        recorded.push(*direct_address);
    }
    recorded
}

pub fn fields_named(fields: &[String], prefix: &str) -> Vec<String> {
    let mut named_fields = Vec::new();
    for field in fields {
        if let Some(field_value) = field.strip_prefix(prefix) {
            named_fields.push(field_value.to_owned());
        }
    }
    named_fields
}

pub fn decode_problem(
    fields: &[String],
    now: DateTime<Utc>,
) -> Option<String> {
    let decoded = decode_rendezvous_record(fields, now);
    decoded.err().map(|error| error.to_string())
}

pub fn describe_malformed_field(field: &str) -> String {
    format!("{MALFORMED_PREFIX}{field}")
}

fn reparse_server(server: &ServerAddress) -> Option<ServerAddress> {
    ServerAddress::parse(&server.to_string()).ok()
}

fn build_moment(seconds_and_nanoseconds: (i64, u32)) -> DateTime<Utc> {
    let (seconds, nanoseconds) = seconds_and_nanoseconds;
    DateTime::from_timestamp(seconds, nanoseconds).unwrap_or_default()
}

fn crowd_peer(parts: (PeerAddress, Vec<SocketAddr>)) -> PeerAddress {
    let (peer_address, direct_addresses) = parts;
    PeerAddress {
        direct_addresses,
        ..peer_address
    }
}

fn build_live_record(
    parts: (ServerAddress, DateTime<Utc>, i64),
) -> LiveRecord {
    let (server, now, seconds_left) = parts;
    let expires_at = now + TimeDelta::seconds(seconds_left);
    let fields = encode_rendezvous_record(&server, expires_at);
    LiveRecord {
        server,
        now,
        expires_at,
        fields,
    }
}

fn shuffle_record_fields(
    record: LiveRecord,
) -> impl Strategy<Value = (LiveRecord, RecordFields)> {
    let shuffled_fields = Just(record.fields.clone()).prop_shuffle();
    (Just(record), shuffled_fields)
}
