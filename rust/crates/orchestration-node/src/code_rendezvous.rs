mod code_announcement;
mod published_codes;
mod rendezvous_record;

use chrono::{DateTime, Utc};
use orchestration_p2p::record_board::RecordBoard;
use orchestration_security::pairing::{PairingCode, derive_rendezvous_secret};

use crate::node_error::NodeError;
use crate::server_address::ServerAddress;

pub(crate) use code_announcement::{announce_code, withdraw_announced_code};
pub(crate) use published_codes::PublishedCodes;
pub use rendezvous_record::{
    MAXIMUM_RECORDED_DIRECT_ADDRESSES, decode_rendezvous_record,
    encode_rendezvous_record,
};

pub async fn find_server_by_code(
    board: &RecordBoard,
    code: &PairingCode,
) -> Result<ServerAddress, NodeError> {
    let record_secret = derive_rendezvous_secret(code)?;
    let fields = board
        .read(&record_secret)
        .await
        .map_err(NodeError::Rendezvous)?;
    decode_rendezvous_record(&fields, Utc::now())
}

async fn publish_server_for_code(
    board: &RecordBoard,
    code: &PairingCode,
    server: &ServerAddress,
    expires_at: DateTime<Utc>,
) -> Result<(), NodeError> {
    let record_secret = derive_rendezvous_secret(code)?;
    let fields = encode_rendezvous_record(server, expires_at);
    board
        .publish(&record_secret, &fields)
        .await
        .map_err(NodeError::Rendezvous)
}

async fn withdraw_code(
    board: &RecordBoard,
    code: &PairingCode,
) -> Result<(), NodeError> {
    let record_secret = derive_rendezvous_secret(code)?;
    board
        .publish(&record_secret, &[])
        .await
        .map_err(NodeError::Rendezvous)
}
