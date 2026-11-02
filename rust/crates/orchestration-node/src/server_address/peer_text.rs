use orchestration_core::peer_address::{
    ENDPOINT_PUBLIC_KEY_LENGTH, PeerAddress,
};
use orchestration_p2p::peer_address::check_peer_address;
use reqwest::Url;
use url::form_urlencoded::Serializer;

use super::PEER_SCHEME_PREFIX;

const RELAY_FIELD: &str = "relay";
const DIRECT_FIELD: &str = "direct";
const QUERY_START: char = '?';

pub(super) fn parse_peer_address(parsed: &Url) -> Option<PeerAddress> {
    let has_extra_parts = parsed.port().is_some()
        || !parsed.username().is_empty()
        || parsed.password().is_some()
        || parsed.fragment().is_some()
        || !parsed.path().is_empty();
    if has_extra_parts {
        return None;
    }
    let key_bytes = hex::decode(parsed.host_str()?).ok()?;
    let endpoint_public_key: [u8; ENDPOINT_PUBLIC_KEY_LENGTH] =
        key_bytes.try_into().ok()?;

    let mut relay_url = None;
    let mut direct_addresses = Vec::new();
    for (field, value) in parsed.query_pairs() {
        match field.as_ref() {
            RELAY_FIELD if relay_url.is_none() => {
                relay_url = Some(value.into_owned());
            }
            DIRECT_FIELD => direct_addresses.push(value.parse().ok()?),
            _ => return None,
        }
    }

    let peer_address = PeerAddress {
        endpoint_public_key,
        direct_addresses,
        relay_url,
    };
    check_peer_address(&peer_address).ok()?;
    Some(peer_address)
}

pub(super) fn render_peer_address(peer_address: &PeerAddress) -> String {
    let key_text = hex::encode(peer_address.endpoint_public_key);
    let mut query = Serializer::new(String::new());
    if let Some(relay_url) = &peer_address.relay_url {
        query.append_pair(RELAY_FIELD, relay_url);
    }
    for direct_address in &peer_address.direct_addresses {
        query.append_pair(DIRECT_FIELD, &direct_address.to_string());
    }

    let query_text = query.finish();
    if query_text.is_empty() {
        return format!("{PEER_SCHEME_PREFIX}{key_text}");
    }
    format!("{PEER_SCHEME_PREFIX}{key_text}{QUERY_START}{query_text}")
}
