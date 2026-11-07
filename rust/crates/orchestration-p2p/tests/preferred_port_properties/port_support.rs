use std::net::{Ipv4Addr, UdpSocket};
use std::time::Duration;

use orchestration_p2p::peer_address::PeerAddress;
use orchestration_p2p::peer_error::PeerError;
use orchestration_p2p::service_endpoint::ServiceEndpoint;
use tokio::io::{AsyncReadExt, AsyncWriteExt};

use crate::link_support::{
    SecretKeyBytes, build_runtime, local_configuration, localhost_address_of,
};

pub const SERVICE_PROTOCOL: &[u8] = b"agents-orchestration/port-service/1";
pub const ANY_FREE_PORT: u16 = 0;
const WORK_LIMIT: Duration = Duration::from_secs(30);
const LATE_WORK: &str = "the endpoint work did not end in time";

pub fn run_bounded<Found>(
    work: impl Future<Output = Result<Found, PeerError>>,
) -> Result<Found, String> {
    let runtime = build_runtime().map_err(|problem| problem.to_string())?;
    runtime.block_on(async {
        let Ok(outcome) = tokio::time::timeout(WORK_LIMIT, work).await else {
            return Err(LATE_WORK.to_owned());
        };
        outcome.map_err(|problem| problem.to_string())
    })
}

pub fn take_udp_port() -> Result<(UdpSocket, u16), String> {
    let taken = UdpSocket::bind((Ipv4Addr::UNSPECIFIED, ANY_FREE_PORT))
        .map_err(|problem| problem.to_string())?;
    let local_address =
        taken.local_addr().map_err(|problem| problem.to_string())?;
    Ok((taken, local_address.port()))
}

pub fn find_free_udp_port() -> Result<u16, String> {
    let (_released, free_port) = take_udp_port()?;
    Ok(free_port)
}

pub fn list_ipv4_ports(peer_address: &PeerAddress) -> Vec<u16> {
    let mut ports = Vec::new();
    for direct_address in &peer_address.direct_addresses {
        if direct_address.is_ipv4() {
            ports.push(direct_address.port());
        }
    }
    ports
}

pub async fn bind_serving_on(
    secret_key: SecretKeyBytes,
    preferred_port: u16,
) -> Result<ServiceEndpoint, PeerError> {
    ServiceEndpoint::bind_preferring_ipv4_port(
        local_configuration(secret_key),
        vec![SERVICE_PROTOCOL.to_vec()],
        preferred_port,
    )
    .await
}

pub async fn echo_through(
    serving: &ServiceEndpoint,
    dialing_secret: SecretKeyBytes,
    payload: &[u8],
) -> Result<Vec<u8>, PeerError> {
    let dialing =
        ServiceEndpoint::bind(local_configuration(dialing_secret), Vec::new())
            .await?;
    let serving_address = localhost_address_of(serving.peer_address());
    let (echoed, answer) = tokio::join!(
        echo_one_stream(serving),
        send_and_read_back(&dialing, &serving_address, payload)
    );
    dialing.close().await;
    echoed?;
    answer
}

async fn echo_one_stream(serving: &ServiceEndpoint) -> Result<(), PeerError> {
    let connection = serving.accept().await?;
    let mut stream = connection.accept_stream().await?;
    let mut received = Vec::new();
    stream
        .read_to_end(&mut received)
        .await
        .map_err(PeerError::Stream)?;
    stream
        .write_all(&received)
        .await
        .map_err(PeerError::Stream)?;
    stream.shutdown().await.map_err(PeerError::Stream)?;
    connection.closed().await;
    Ok(())
}

async fn send_and_read_back(
    dialing: &ServiceEndpoint,
    serving_address: &PeerAddress,
    payload: &[u8],
) -> Result<Vec<u8>, PeerError> {
    let connection =
        dialing.connect(serving_address, SERVICE_PROTOCOL).await?;
    let mut stream = connection.open_stream().await?;
    stream.write_all(payload).await.map_err(PeerError::Stream)?;
    stream.shutdown().await.map_err(PeerError::Stream)?;
    let mut answer = Vec::new();
    stream
        .read_to_end(&mut answer)
        .await
        .map_err(PeerError::Stream)?;
    connection.close();
    Ok(answer)
}
