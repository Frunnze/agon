use std::time::Duration;

use orchestration_core::peer_address::PeerAddress;
use orchestration_node::node_error::NodeError;
use orchestration_node::server_address::ServerAddress;
use orchestration_p2p::peer_configuration::{PeerConfiguration, RelayChoice};
use orchestration_p2p::service_endpoint::ServiceEndpoint;
use orchestration_security::peer_addresses::generate_peer_secret;
use proptest::prelude::*;
use serde_json::{Value, json};
use tokio::task::JoinSet;
use tokio::time::timeout;

use crate::hosting_desk::{
    heavy_cases, host_a_server, read_group_at, read_hosted_peer_address,
    read_own_group, shared_hosting, use_server_within,
};
use crate::support::runner_access::test_runtime;
use crate::support::test_device::{describe, fail};

const WRONG_PROTOCOL: &[u8] = b"agents-orchestration/not-the-app-server/0";
const HANDSHAKE_LIMIT: Duration = Duration::from_secs(20);
const LATE_HANDSHAKE: &str = "the refused handshake did not end in time";

fn refuse_a_handshake(peer_address: &PeerAddress) -> Result<bool, String> {
    let runtime = test_runtime()?;
    runtime.block_on(async {
        let secret_key = generate_peer_secret().map_err(describe)?;
        let configuration = PeerConfiguration {
            secret_key: *secret_key,
            relay: RelayChoice::Disabled,
        };
        let endpoint = ServiceEndpoint::bind(configuration, Vec::new())
            .await
            .map_err(describe)?;
        let connecting = endpoint.connect(peer_address, WRONG_PROTOCOL);
        let attempt = timeout(HANDSHAKE_LIMIT, connecting).await;
        endpoint.close().await;
        let connected = attempt.map_err(|_| LATE_HANDSHAKE.to_owned())?;
        Ok(connected.is_err())
    })
}

fn check_health_over(route: &ServerAddress) -> Result<(), String> {
    use_server_within(route, async |server| server.check_health().await)
}

proptest! {
    #![proptest_config(heavy_cases(2))]

    #[test]
    fn test_serve_over_peer_link_property_answers_fresh_links(
        link_count in 1_usize..4,
    ) {
        let hosting = shared_hosting().map_err(fail)?;
        let peer_address =
            read_hosted_peer_address(&hosting.device).map_err(fail)?;
        let route = ServerAddress::Peer(peer_address);

        for _ in 0..link_count {
            let answered = check_health_over(&route);
            prop_assert_eq!(answered, Ok(()));
        }
    }

    #[test]
    fn test_serve_over_peer_link_property_a_refused_handshake_keeps_serving(
        refusal_count in 1_usize..3,
    ) {
        let hosting = shared_hosting().map_err(fail)?;
        let peer_address =
            read_hosted_peer_address(&hosting.device).map_err(fail)?;

        for _ in 0..refusal_count {
            let refused = refuse_a_handshake(&peer_address).map_err(fail)?;
            prop_assert!(refused);
        }
        let route = ServerAddress::Peer(peer_address);
        let answered = check_health_over(&route);

        prop_assert_eq!(answered, Ok(()));
    }

    #[test]
    fn test_serve_over_peer_link_property_ends_when_forgotten(
        _round in 0_u8..2,
    ) {
        let hosting = host_a_server().map_err(fail)?;
        let peer_address =
            read_hosted_peer_address(&hosting.device).map_err(fail)?;

        let forgotten = hosting
            .device
            .run(&json!({ "command": "forget_this_device" }));
        let route = ServerAddress::Peer(peer_address);
        let answered = check_health_over(&route);

        prop_assert_eq!(forgotten, Ok(Value::Null));
        prop_assert!(answered.is_err(), "{answered:?}");
    }

    #[test]
    fn test_serve_connection_property_one_link_serves_many_requests(
        request_count in 2_usize..10,
    ) {
        let hosting = shared_hosting().map_err(fail)?;
        let peer_address =
            read_hosted_peer_address(&hosting.device).map_err(fail)?;

        let answered = use_server_within(
            &ServerAddress::Peer(peer_address),
            async |server| {
                for _ in 0..request_count {
                    server.check_health().await?;
                }
                Ok(())
            },
        );

        prop_assert_eq!(answered, Ok(()));
    }

    #[test]
    fn test_serve_connection_property_concurrent_streams_all_answer(
        request_count in 2_usize..8,
    ) {
        let hosting = shared_hosting().map_err(fail)?;
        let peer_address =
            read_hosted_peer_address(&hosting.device).map_err(fail)?;

        let answered = use_server_within(
            &ServerAddress::Peer(peer_address),
            async |server| {
                let mut requests = JoinSet::new();
                for _ in 0..request_count {
                    let client = server.clone();
                    requests.spawn(async move { client.check_health().await });
                }
                let mut answered_count: usize = 0;
                while let Some(joined) = requests.join_next().await {
                    let answer = joined.map_err(|problem| {
                        NodeError::ServerUnreachable(problem.to_string())
                    })?;
                    answer?;
                    answered_count += 1;
                }
                Ok(answered_count)
            },
        );

        prop_assert_eq!(answered, Ok(request_count));
    }

    #[test]
    fn test_serve_connection_property_signed_reads_match_the_loopback(
        _round in 0_u8..2,
    ) {
        let hosting = shared_hosting().map_err(fail)?;
        let peer_address =
            read_hosted_peer_address(&hosting.device).map_err(fail)?;

        let over_peer = read_group_at(
            &hosting.device,
            &ServerAddress::Peer(peer_address),
        )
        .map_err(fail)?;
        let over_loopback =
            read_own_group(&hosting.device, hosting.port).map_err(fail)?;

        prop_assert_eq!(&over_peer.group.term, &over_loopback.group.term);
        prop_assert_eq!(over_peer.standing, over_loopback.standing);
    }
}
