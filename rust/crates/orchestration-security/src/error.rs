use thiserror::Error;

#[derive(Clone, Copy, Debug, PartialEq, Eq, Error)]
pub enum AuditChainProblem {
    #[error("the entry index is out of sequence")]
    WrongIndex,
    #[error("the previous hash does not match the entry before")]
    WrongPreviousHash,
    #[error("the entry hash does not match its content")]
    WrongHash,
    #[error("the signing device is unknown")]
    UnknownSigner,
    #[error("the entry signature is invalid")]
    InvalidSignature,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Error)]
pub enum SecurityError {
    #[error("the operating system random source failed")]
    RandomSourceFailed,
    #[error("the key has the wrong length or form")]
    InvalidKey,
    #[error("the signature is malformed or does not match")]
    InvalidSignature,
    #[error("the signer key does not belong to the named device")]
    SignerMismatch,
    #[error("the pairing code is malformed")]
    MalformedPairingCode,
    #[error("the pairing session has expired")]
    PairingSessionExpired,
    #[error("the pairing code does not match the session")]
    PairingCodeMismatch,
    #[error("encryption failed")]
    EncryptionFailed,
    #[error("the ciphertext could not be decrypted")]
    DecryptionFailed,
    #[error("the sealed text is malformed")]
    MalformedSealedText,
    #[error("the signed content could not be serialized")]
    SerializationFailed,
    #[error("the audit chain is broken at entry {index}: {problem}")]
    AuditChainBroken {
        index: usize,
        problem: AuditChainProblem,
    },
    #[error("the request timestamp is outside the allowed window")]
    RequestTimestampOutsideWindow,
    #[error("a request signing header is malformed")]
    MalformedRequestHeader,
    #[error("the rendezvous key could not be derived from the code")]
    RendezvousNotDerived,
    #[error("a pairing nonce has the wrong length")]
    MalformedPairingNonce,
    #[error("the trusted device's nonce does not open its commitment")]
    PairingCommitmentMismatch,
}
