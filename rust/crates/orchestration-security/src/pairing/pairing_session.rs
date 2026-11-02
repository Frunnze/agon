use chrono::{DateTime, TimeDelta, Utc};
use serde::{Deserialize, Serialize};

use crate::error::SecurityError;
use crate::pairing::pairing_code::PairingCode;

pub const PAIRING_SESSION_LIFETIME: TimeDelta = TimeDelta::minutes(5);

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct PairingSession {
    pub code: PairingCode,
    pub started_at: DateTime<Utc>,
}

impl PairingSession {
    pub fn start(started_at: DateTime<Utc>) -> Result<Self, SecurityError> {
        Ok(Self {
            code: PairingCode::generate()?,
            started_at,
        })
    }

    #[must_use]
    pub fn is_expired(&self, now: DateTime<Utc>) -> bool {
        let elapsed = now.signed_duration_since(self.started_at);
        elapsed >= PAIRING_SESSION_LIFETIME
    }

    pub fn verify_join(
        &self,
        offered_code: &PairingCode,
        now: DateTime<Utc>,
    ) -> Result<(), SecurityError> {
        if self.is_expired(now) {
            return Err(SecurityError::PairingSessionExpired);
        }
        if offered_code != &self.code {
            return Err(SecurityError::PairingCodeMismatch);
        }
        Ok(())
    }
}
