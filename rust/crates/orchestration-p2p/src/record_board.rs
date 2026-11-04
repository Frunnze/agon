use std::any::Any;
use std::error::Error;
use std::time::Duration;

use iroh::SecretKey;
use iroh_dns::pkarr::SignedPacket;
use reqwest::{Client, StatusCode};

use crate::board_retry::retry_transient_board_problems;
use crate::peer_configuration::SECRET_KEY_LENGTH;
use crate::peer_error::PeerError;

pub const PUBLIC_RECORD_BOARD: &str = "https://dns.iroh.link/pkarr";
const RECORD_NAME: &str = "_agents-orchestration";
const RECORD_TIME_TO_LIVE_SECONDS: u32 = 30;
const BOARD_REQUEST_TIMEOUT: Duration = Duration::from_secs(15);
const PATH_SEPARATOR: char = '/';
const CAUSE_SEPARATOR: &str = ": ";

pub type RecordFields = Vec<String>;
type RelayPayload = Vec<u8>;

#[derive(Clone, Debug)]
pub struct RecordBoard {
    http_client: Client,
}

impl RecordBoard {
    pub(crate) fn open(
        tls_configuration: impl Any,
    ) -> Result<Self, PeerError> {
        let http_client = Client::builder()
            .tls_backend_preconfigured(tls_configuration)
            .timeout(BOARD_REQUEST_TIMEOUT)
            .build()
            .map_err(|problem| describe_board_problem(&problem))?;
        Ok(Self { http_client })
    }

    pub async fn publish(
        &self,
        record_secret: &[u8; SECRET_KEY_LENGTH],
        fields: &[String],
    ) -> Result<(), PeerError> {
        let secret_key = SecretKey::from_bytes(record_secret);
        let packet = SignedPacket::from_txt_strings(
            &secret_key,
            RECORD_NAME,
            fields,
            RECORD_TIME_TO_LIVE_SECONDS,
        )
        .map_err(|problem| PeerError::RecordNotBuilt(problem.to_string()))?;

        let board_address = locate_record(&secret_key);
        let payload = packet.to_relay_payload();
        retry_transient_board_problems(|| {
            self.put_payload(&board_address, payload.clone())
        })
        .await
    }

    pub async fn read(
        &self,
        record_secret: &[u8; SECRET_KEY_LENGTH],
    ) -> Result<RecordFields, PeerError> {
        let secret_key = SecretKey::from_bytes(record_secret);
        let board_address = locate_record(&secret_key);
        let published_payload = retry_transient_board_problems(|| {
            self.fetch_published_payload(&board_address)
        })
        .await?;
        let Some(payload) = published_payload else {
            return Ok(Vec::new());
        };

        let packet =
            SignedPacket::from_relay_payload(&secret_key.public(), &payload)
                .map_err(|problem| {
                PeerError::UnreadableRecord(problem.to_string())
            })?;
        Ok(packet.txt_records(RECORD_NAME))
    }

    async fn put_payload(
        &self,
        board_address: &str,
        payload: RelayPayload,
    ) -> Result<(), PeerError> {
        let response = self
            .http_client
            .put(board_address)
            .body(payload)
            .send()
            .await
            .map_err(|problem| describe_board_problem(&problem))?;
        let status = response.status();
        if !status.is_success() {
            return Err(PeerError::RecordRefused(status.as_u16()));
        }
        Ok(())
    }

    async fn fetch_published_payload(
        &self,
        board_address: &str,
    ) -> Result<Option<RelayPayload>, PeerError> {
        let response = self
            .http_client
            .get(board_address)
            .send()
            .await
            .map_err(|problem| describe_board_problem(&problem))?;
        let status = response.status();
        if status == StatusCode::NOT_FOUND {
            return Ok(None);
        }
        if !status.is_success() {
            return Err(PeerError::RecordRefused(status.as_u16()));
        }

        let payload = response
            .bytes()
            .await
            .map_err(|problem| describe_board_problem(&problem))?;
        Ok(Some(payload.to_vec()))
    }
}

fn locate_record(secret_key: &SecretKey) -> String {
    let record_key = secret_key.public().to_z32();
    format!("{PUBLIC_RECORD_BOARD}{PATH_SEPARATOR}{record_key}")
}

fn describe_board_problem(problem: &reqwest::Error) -> PeerError {
    let mut description = problem.to_string();
    let mut cause = problem.source();
    while let Some(inner_problem) = cause {
        description.push_str(CAUSE_SEPARATOR);
        description.push_str(&inner_problem.to_string());
        cause = inner_problem.source();
    }
    PeerError::RecordBoardUnreachable(description)
}
