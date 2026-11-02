use std::collections::BTreeMap;
use std::sync::{Mutex, MutexGuard, PoisonError};

use orchestration_security::pairing::{PairingCode, PairingTranscript};

#[derive(Debug)]
struct ApproverPairing {
    approver_nonce: Vec<u8>,
    transcript: Option<PairingTranscript>,
}

#[derive(Debug, Default)]
pub(crate) struct ApproverPairings {
    pairings: Mutex<BTreeMap<String, ApproverPairing>>,
}

impl ApproverPairings {
    pub(crate) fn remember_nonce(
        &self,
        code: &PairingCode,
        approver_nonce: Vec<u8>,
    ) {
        let pairing = ApproverPairing {
            approver_nonce,
            transcript: None,
        };
        self.lock_pairings()
            .insert(String::from(code.clone()), pairing);
    }

    pub(crate) fn find_approver_nonce(
        &self,
        code: &PairingCode,
    ) -> Option<Vec<u8>> {
        let pairings = self.lock_pairings();
        let pairing = pairings.get(&String::from(code.clone()))?;
        Some(pairing.approver_nonce.clone())
    }

    pub(crate) fn pin_transcript(
        &self,
        candidate: PairingTranscript,
    ) -> Option<PairingTranscript> {
        let mut pairings = self.lock_pairings();
        let code_key = String::from(candidate.code.clone());
        let pairing = pairings.get_mut(&code_key)?;
        let pinned = pairing.transcript.get_or_insert(candidate);
        Some(pinned.clone())
    }

    pub(crate) fn forget(&self, code: &PairingCode) {
        self.lock_pairings().remove(&String::from(code.clone()));
    }

    fn lock_pairings(
        &self,
    ) -> MutexGuard<'_, BTreeMap<String, ApproverPairing>> {
        self.pairings.lock().unwrap_or_else(PoisonError::into_inner)
    }
}
