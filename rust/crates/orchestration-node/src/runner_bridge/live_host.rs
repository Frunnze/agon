use std::path::PathBuf;
use std::sync::Arc;

use chrono::Utc;
use orchestration_api::work::{RunEvent, RunEventsRequest};
use orchestration_core::device::RunnerLink;
use orchestration_core::identifiers::RunId;
use orchestration_core::run::{ChatAuthor, ChatMessage};
use orchestration_p2p::peer_endpoint::PeerEndpoint;
use orchestration_p2p::peer_error::PeerError;
use orchestration_p2p::peer_link::{
    PeerLink, PeerLinkReceiver, PeerLinkSender,
};
use orchestration_runner::runner_server::RunnerServer;
use tokio::runtime::Runtime;
use tokio::sync::broadcast::error::RecvError;
use tokio::task::JoinHandle;

use super::file_host::answer_file_request;
use super::node_runner_server::NodeRunnerServer;
use crate::live_link_messages::{
    ClientMessage, RunnerMessage, decode_link_message, encode_link_message,
};
use crate::node_error::NodeError;

const EXPECTED_FIRST_REQUEST: &str =
    "the first message must ask to watch a run or to see files";

pub(crate) fn start_live_host(
    runtime: &Runtime,
    endpoint: Arc<PeerEndpoint>,
    server: Arc<NodeRunnerServer>,
    cache_root: PathBuf,
) -> JoinHandle<()> {
    runtime.spawn(async move {
        loop {
            match endpoint.accept().await {
                Ok(link) => {
                    let peer_server = Arc::clone(&server);
                    let peer_cache_root = cache_root.clone();
                    tokio::spawn(serve_peer(
                        peer_server,
                        peer_cache_root,
                        link,
                    ));
                }
                Err(PeerError::EndpointClosed) => return,
                Err(_failed_handshake) => {}
            }
        }
    })
}

async fn serve_peer(
    server: Arc<NodeRunnerServer>,
    cache_root: PathBuf,
    link: PeerLink,
) {
    let PeerLink {
        sender,
        mut receiver,
    } = link;
    let first_message = match read_first_message(&mut receiver).await {
        Ok(first_message) => first_message,
        Err(problem) => return refuse(sender, &problem).await,
    };
    match first_message {
        ClientMessage::Watch { run_id } => {
            serve_watcher(&server, sender, receiver, run_id).await;
        }
        ClientMessage::Browse { request } => {
            let reader_key = sender.remote_public_key();
            let answering = answer_file_request(
                &server,
                &cache_root,
                &reader_key,
                request,
            );
            match answering.await {
                Ok(answer) => {
                    let answered = RunnerMessage::Answered { answer };
                    finish_with(sender, &answered).await;
                }
                Err(problem) => refuse(sender, &problem).await,
            }
        }
        ClientMessage::Chat { .. } => {
            let reason = EXPECTED_FIRST_REQUEST.to_owned();
            refuse(sender, &NodeError::MalformedLinkMessage(reason)).await;
        }
    }
}

async fn read_first_message(
    receiver: &mut PeerLinkReceiver,
) -> Result<ClientMessage, NodeError> {
    let first_frame = receiver.receive_frame().await?;
    let first_frame = first_frame.ok_or(NodeError::UntrustedPeer)?;
    decode_link_message(&first_frame)
}

async fn serve_watcher(
    server: &NodeRunnerServer,
    mut sender: PeerLinkSender,
    mut receiver: PeerLinkReceiver,
    run_id: RunId,
) {
    let watcher_key = sender.remote_public_key();
    if let Err(problem) = server.authorize_watcher(run_id, &watcher_key).await
    {
        return refuse(sender, &problem).await;
    }
    if send_message(&mut sender, &RunnerMessage::Accepted)
        .await
        .is_err()
    {
        return;
    }

    let link_kind = sender.link_kind();
    post_link_change(server, run_id, link_kind).await;
    tokio::select! {
        () = forward_live_updates(server, &mut sender, run_id) => {}
        () = relay_watcher_chat(server, &mut receiver, run_id) => {}
    }
    post_link_change(server, run_id, RunnerLink::Unreachable).await;
}

async fn refuse(sender: PeerLinkSender, problem: &NodeError) {
    let refusal = RunnerMessage::Refused {
        reason: problem.to_string(),
    };
    finish_with(sender, &refusal).await;
}

async fn finish_with(mut sender: PeerLinkSender, message: &RunnerMessage) {
    if send_message(&mut sender, message).await.is_ok() {
        let _link_closed = sender.close().await;
    }
}

async fn forward_live_updates(
    server: &NodeRunnerServer,
    sender: &mut PeerLinkSender,
    run_id: RunId,
) {
    let mut updates = server.subscribe_to_live_updates();
    loop {
        let update = match updates.recv().await {
            Ok(update) => update,
            Err(RecvError::Lagged(_missed_updates)) => continue,
            Err(RecvError::Closed) => return,
        };
        if update.run_id != run_id {
            continue;
        }
        let message = RunnerMessage::Events {
            events: update.events,
        };
        if send_message(sender, &message).await.is_err() {
            return;
        }
    }
}

async fn relay_watcher_chat(
    server: &NodeRunnerServer,
    receiver: &mut PeerLinkReceiver,
    run_id: RunId,
) {
    while let Ok(Some(frame)) = receiver.receive_frame().await {
        let Ok(ClientMessage::Chat { text }) = decode_link_message(&frame)
        else {
            return;
        };
        let message = ChatMessage {
            at: Utc::now(),
            author: ChatAuthor::You,
            text,
            is_error: false,
            waiting_to_send: false,
        };
        let request = RunEventsRequest {
            events: vec![RunEvent::ChatAppended { message }],
        };
        if server.post_run_events(run_id, &request).await.is_err() {
            return;
        }
    }
}

async fn post_link_change(
    server: &NodeRunnerServer,
    run_id: RunId,
    link: RunnerLink,
) {
    let request = RunEventsRequest {
        events: vec![RunEvent::LinkChanged { link }],
    };
    let _link_recorded = server.post_run_events(run_id, &request).await;
}

async fn send_message(
    sender: &mut PeerLinkSender,
    message: &RunnerMessage,
) -> Result<(), NodeError> {
    let frame = encode_link_message(message)?;
    sender.send_frame(&frame).await?;
    Ok(())
}
