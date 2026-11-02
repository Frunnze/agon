use orchestration_node::code_rendezvous::find_server_by_code;
use orchestration_node::server_address::ServerAddress;
use orchestration_p2p::peer_configuration::{PeerConfiguration, RelayChoice};
use orchestration_p2p::peer_endpoint::PeerEndpoint;
use orchestration_security::pairing::PairingCode;
use orchestration_security::peer_addresses::generate_peer_secret;

use super::runner_access::test_runtime;
use super::test_device::describe;

pub fn look_up_code(code_text: &str) -> Result<ServerAddress, String> {
    let code = PairingCode::parse(code_text).map_err(describe)?;
    let secret_key = generate_peer_secret().map_err(describe)?;
    let runtime = test_runtime()?;
    runtime.block_on(async {
        let configuration = PeerConfiguration {
            secret_key: *secret_key,
            relay: RelayChoice::Disabled,
        };
        let endpoint =
            PeerEndpoint::bind(configuration).await.map_err(describe)?;
        let board = endpoint.open_record_board().map_err(describe);
        let found = match board {
            Ok(board) => {
                find_server_by_code(&board, &code).await.map_err(describe)
            }
            Err(problem) => Err(problem),
        };
        endpoint.close().await;
        found
    })
}

pub fn generate_unissued_code() -> Result<String, String> {
    let code = PairingCode::generate().map_err(describe)?;
    Ok(code.display())
}
