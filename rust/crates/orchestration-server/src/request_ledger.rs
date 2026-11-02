use std::collections::BTreeMap;

use chrono::{DateTime, Utc};
use orchestration_core::identifiers::DeviceId;
use orchestration_security::request_signing::{
    REQUEST_TIMESTAMP_WINDOW, RequestNonce, RequestSignature,
};

use crate::error::ServerError;

pub type Presence = BTreeMap<DeviceId, DateTime<Utc>>;

type NonceKey = (DeviceId, RequestNonce);

#[derive(Debug, Default)]
pub struct RequestLedger {
    presence: Presence,
    seen_nonces: BTreeMap<NonceKey, DateTime<Utc>>,
}

impl RequestLedger {
    pub fn admit(
        &mut self,
        request_signature: &RequestSignature,
        now: DateTime<Utc>,
    ) -> Result<(), ServerError> {
        let oldest_allowed_timestamp = now - REQUEST_TIMESTAMP_WINDOW;
        self.seen_nonces.retain(|_nonce_key, timestamp| {
            *timestamp >= oldest_allowed_timestamp
        });
        let nonce_key =
            (request_signature.device_id.clone(), request_signature.nonce);
        if self.seen_nonces.contains_key(&nonce_key) {
            return Err(ServerError::Unauthenticated(
                "the request was already used",
            ));
        }

        self.seen_nonces
            .insert(nonce_key, request_signature.timestamp);
        self.presence
            .insert(request_signature.device_id.clone(), now);
        Ok(())
    }

    pub fn presence(&self) -> Presence {
        self.presence.clone()
    }
}
