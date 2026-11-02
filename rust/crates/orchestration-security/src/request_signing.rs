use chrono::{DateTime, SecondsFormat, TimeDelta, Utc};
use orchestration_core::identifiers::DeviceId;
use serde::{Deserialize, Serialize};

use crate::canonical_message::{encode_canonical_message, encode_timestamp};
use crate::error::SecurityError;
use crate::identity::{DeviceIdentity, device_id_for, verify_signature};
use crate::random_source::random_bytes;

pub const DEVICE_ID_HEADER: &str = "x-device-id";
pub const TIMESTAMP_HEADER: &str = "x-timestamp";
pub const SIGNATURE_HEADER: &str = "x-signature";
pub const NONCE_HEADER: &str = "x-nonce";
pub const REQUEST_NONCE_LENGTH: usize = 16;
pub const REQUEST_TIMESTAMP_WINDOW: TimeDelta = TimeDelta::minutes(5);
const REQUEST_DOMAIN: &str = "orchestration-http-request-v2";

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct RequestSignature {
    pub device_id: DeviceId,
    pub timestamp: DateTime<Utc>,
    pub nonce: RequestNonce,
    pub signature: Vec<u8>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct RequestHeaderValues {
    pub device_id: String,
    pub timestamp: String,
    pub nonce: String,
    pub signature: String,
}

pub type RequestNonce = [u8; REQUEST_NONCE_LENGTH];

impl RequestSignature {
    #[must_use]
    pub fn to_header_values(&self) -> RequestHeaderValues {
        RequestHeaderValues {
            device_id: self.device_id.0.clone(),
            timestamp: self
                .timestamp
                .to_rfc3339_opts(SecondsFormat::Nanos, true),
            nonce: hex::encode(self.nonce),
            signature: hex::encode(&self.signature),
        }
    }

    pub fn from_header_values(
        header_values: &RequestHeaderValues,
    ) -> Result<Self, SecurityError> {
        let timestamp = DateTime::parse_from_rfc3339(&header_values.timestamp)
            .map_err(|_| SecurityError::MalformedRequestHeader)?;
        let signature = hex::decode(&header_values.signature)
            .map_err(|_| SecurityError::MalformedRequestHeader)?;
        let nonce_bytes = hex::decode(&header_values.nonce)
            .map_err(|_| SecurityError::MalformedRequestHeader)?;
        let nonce: RequestNonce = nonce_bytes
            .try_into()
            .map_err(|_| SecurityError::MalformedRequestHeader)?;

        Ok(Self {
            device_id: DeviceId(header_values.device_id.clone()),
            timestamp: timestamp.with_timezone(&Utc),
            nonce,
            signature,
        })
    }
}

pub fn sign_request(
    identity: &DeviceIdentity,
    method: &str,
    path: &str,
    timestamp: DateTime<Utc>,
    body: &[u8],
) -> Result<RequestSignature, SecurityError> {
    let nonce = *random_bytes::<REQUEST_NONCE_LENGTH>()?;
    let content = RequestContent {
        method,
        path,
        timestamp,
        nonce: &nonce,
        body,
    };
    let message = encode_request(&content);

    Ok(RequestSignature {
        device_id: identity.device_id(),
        timestamp,
        nonce,
        signature: identity.sign(&message),
    })
}

pub fn verify_request(
    request_signature: &RequestSignature,
    signer_key: &[u8],
    method: &str,
    path: &str,
    body: &[u8],
    now: DateTime<Utc>,
) -> Result<(), SecurityError> {
    if device_id_for(signer_key) != request_signature.device_id {
        return Err(SecurityError::SignerMismatch);
    }

    let clock_distance =
        now.signed_duration_since(request_signature.timestamp).abs();
    if clock_distance > REQUEST_TIMESTAMP_WINDOW {
        return Err(SecurityError::RequestTimestampOutsideWindow);
    }

    let content = RequestContent {
        method,
        path,
        timestamp: request_signature.timestamp,
        nonce: &request_signature.nonce,
        body,
    };
    let message = encode_request(&content);
    verify_signature(signer_key, &message, &request_signature.signature)
}

struct RequestContent<'request> {
    method: &'request str,
    path: &'request str,
    timestamp: DateTime<Utc>,
    nonce: &'request RequestNonce,
    body: &'request [u8],
}

fn encode_request(content: &RequestContent<'_>) -> Vec<u8> {
    let encoded_timestamp = encode_timestamp(content.timestamp);
    encode_canonical_message(
        REQUEST_DOMAIN,
        &[
            content.method.as_bytes(),
            content.path.as_bytes(),
            &encoded_timestamp,
            content.nonce,
            content.body,
        ],
    )
}
