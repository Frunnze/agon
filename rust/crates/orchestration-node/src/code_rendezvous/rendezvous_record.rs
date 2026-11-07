use std::net::SocketAddr;

use chrono::{DateTime, Utc};

use crate::node_error::NodeError;
use crate::server_address::ServerAddress;

pub const MAXIMUM_RECORDED_DIRECT_ADDRESSES: usize = 8;
const EXPIRY_FIELD: &str = "expires";
const SERVER_FIELD: &str = "server";
const DIRECT_FIELD: &str = "direct";
const FIELD_SEPARATOR: char = '=';

#[must_use]
pub fn encode_rendezvous_record(
    server: &ServerAddress,
    expires_at: DateTime<Utc>,
) -> Vec<String> {
    let bare_server = server.without_direct_addresses();
    let mut fields = vec![
        format!("{EXPIRY_FIELD}{FIELD_SEPARATOR}{}", expires_at.timestamp()),
        format!("{SERVER_FIELD}{FIELD_SEPARATOR}{bare_server}"),
    ];
    let recorded_addresses = server
        .direct_addresses()
        .iter()
        .take(MAXIMUM_RECORDED_DIRECT_ADDRESSES);
    for direct_address in recorded_addresses {
        fields
            .push(format!("{DIRECT_FIELD}{FIELD_SEPARATOR}{direct_address}"));
    }
    fields
}

pub fn decode_rendezvous_record(
    fields: &[String],
    now: DateTime<Utc>,
) -> Result<ServerAddress, NodeError> {
    if fields.is_empty() {
        return Err(NodeError::NoServerAcceptedCode);
    }
    let mut expiry_seconds = None;
    let mut server = None;
    let mut direct_addresses: Vec<SocketAddr> = Vec::new();
    for field in fields {
        let (name, value) = field
            .split_once(FIELD_SEPARATOR)
            .ok_or_else(|| describe_malformed(field))?;
        let has_room_for_direct =
            direct_addresses.len() < MAXIMUM_RECORDED_DIRECT_ADDRESSES;
        match name {
            EXPIRY_FIELD if expiry_seconds.is_none() => {
                let seconds: i64 =
                    value.parse().map_err(|_| describe_malformed(field))?;
                expiry_seconds = Some(seconds);
            }
            SERVER_FIELD if server.is_none() => {
                server = Some(parse_bare_server(field, value)?);
            }
            DIRECT_FIELD if has_room_for_direct => {
                let address =
                    value.parse().map_err(|_| describe_malformed(field))?;
                direct_addresses.push(address);
            }
            _ => return Err(describe_malformed(field)),
        }
    }

    let expiry_seconds =
        expiry_seconds.ok_or_else(|| describe_malformed(EXPIRY_FIELD))?;
    let server = server.ok_or_else(|| describe_malformed(SERVER_FIELD))?;
    let is_web_server = matches!(server, ServerAddress::Web(_));
    if is_web_server && !direct_addresses.is_empty() {
        return Err(describe_malformed(DIRECT_FIELD));
    }
    if now.timestamp() >= expiry_seconds {
        return Err(NodeError::NoServerAcceptedCode);
    }
    Ok(server.with_direct_addresses(&direct_addresses))
}

fn parse_bare_server(
    field: &str,
    value: &str,
) -> Result<ServerAddress, NodeError> {
    let server =
        ServerAddress::parse(value).map_err(|_| describe_malformed(field))?;
    if !server.direct_addresses().is_empty() {
        return Err(describe_malformed(field));
    }
    Ok(server)
}

fn describe_malformed(field: &str) -> NodeError {
    NodeError::MalformedRendezvousRecord(field.to_owned())
}
