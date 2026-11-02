use std::collections::BTreeMap;
use std::sync::{Arc, Mutex, MutexGuard, PoisonError};

use chrono::{DateTime, Utc};
use orchestration_api::work::RunEvent;
use orchestration_core::device::RunnerLink;
use orchestration_core::identifiers::RunId;
use orchestration_core::run_links::is_connected;
use orchestration_p2p::peer_link::{
    PeerLink, PeerLinkReceiver, PeerLinkSender,
};
use serde::Serialize;
use tokio::sync::Mutex as AsyncMutex;
use tokio::task::JoinHandle;

use crate::live_link_messages::{
    ClientMessage, RunnerMessage, decode_link_message, encode_link_message,
};
use crate::node_error::NodeError;

type SharedSender = Arc<AsyncMutex<PeerLinkSender>>;
type WatchTable = Arc<Mutex<BTreeMap<RunId, WatchState>>>;
pub(crate) type LinkReport = (RunnerLink, Option<DateTime<Utc>>);

const FILES_DURING_WATCH: &str = "the runner sent files during a watch";

#[derive(Debug)]
struct WatchState {
    link: RunnerLink,
    link_lost_at: Option<DateTime<Utc>>,
    problem: Option<String>,
    undelivered: Vec<RunEvent>,
    sender: Option<SharedSender>,
    reader: Option<JoinHandle<()>>,
}

#[derive(Debug, Serialize)]
pub(crate) struct WatchView {
    link: RunnerLink,
    link_lost_at: Option<DateTime<Utc>>,
    problem: Option<String>,
    events: Vec<RunEvent>,
}

#[derive(Debug, Default)]
pub(crate) struct LiveWatches {
    table: WatchTable,
}

impl WatchState {
    fn unreachable() -> Self {
        Self {
            link: RunnerLink::Unreachable,
            link_lost_at: None,
            problem: None,
            undelivered: Vec::new(),
            sender: None,
            reader: None,
        }
    }

    fn lose_link(&mut self, problem: Option<String>) {
        if is_connected(self.link) {
            self.link_lost_at = Some(Utc::now());
        }
        self.link = RunnerLink::Unreachable;
        self.sender = None;
        self.reader = None;
        self.problem = problem;
    }
}

impl LiveWatches {
    pub(crate) fn is_linked(&self, run_id: RunId) -> bool {
        let table = lock_table(&self.table);
        table
            .get(&run_id)
            .is_some_and(|state| state.sender.is_some())
    }

    pub(crate) fn link_report(&self, run_id: RunId) -> Option<LinkReport> {
        let table = lock_table(&self.table);
        table
            .get(&run_id)
            .map(|state| (state.link, state.link_lost_at))
    }

    pub(crate) fn take_view(&self, run_id: RunId) -> WatchView {
        let mut table = lock_table(&self.table);
        let state =
            table.entry(run_id).or_insert_with(WatchState::unreachable);
        WatchView {
            link: state.link,
            link_lost_at: state.link_lost_at,
            problem: state.problem.clone(),
            events: std::mem::take(&mut state.undelivered),
        }
    }

    pub(crate) fn start(&self, run_id: RunId, link: PeerLink) {
        let PeerLink { sender, receiver } = link;
        let link_kind = sender.link_kind();
        let shared_table = Arc::clone(&self.table);
        let reader =
            tokio::spawn(read_host_messages(shared_table, run_id, receiver));

        let mut table = lock_table(&self.table);
        let previous = table.remove(&run_id);
        let undelivered =
            previous.map(|state| state.undelivered).unwrap_or_default();
        table.insert(
            run_id,
            WatchState {
                link: link_kind,
                link_lost_at: None,
                problem: None,
                undelivered,
                sender: Some(Arc::new(AsyncMutex::new(sender))),
                reader: Some(reader),
            },
        );
    }

    pub(crate) fn record_unreachable(
        &self,
        run_id: RunId,
        problem: &NodeError,
    ) {
        let mut table = lock_table(&self.table);
        let state =
            table.entry(run_id).or_insert_with(WatchState::unreachable);
        state.lose_link(Some(problem.to_string()));
    }

    pub(crate) async fn send_chat(
        &self,
        run_id: RunId,
        text: &str,
    ) -> Result<bool, NodeError> {
        let sender = {
            let table = lock_table(&self.table);
            table.get(&run_id).and_then(|state| state.sender.clone())
        };
        let Some(sender) = sender else {
            return Ok(false);
        };
        let chat = ClientMessage::Chat {
            text: text.to_owned(),
        };
        let frame = encode_link_message(&chat)?;
        let sent = sender.lock().await.send_frame(&frame).await;
        match sent {
            Ok(()) => Ok(true),
            Err(problem) => {
                let problem = NodeError::from(problem);
                self.record_unreachable(run_id, &problem);
                Ok(false)
            }
        }
    }

    pub(crate) fn stop(&self, run_id: RunId) {
        let removed = lock_table(&self.table).remove(&run_id);
        let reader = removed.and_then(|state| state.reader);
        if let Some(reader) = reader {
            reader.abort();
        }
    }
}

async fn read_host_messages(
    table: WatchTable,
    run_id: RunId,
    mut receiver: PeerLinkReceiver,
) {
    let ending_problem = loop {
        let frame = match receiver.receive_frame().await {
            Ok(Some(frame)) => frame,
            Ok(None) => break None,
            Err(problem) => break Some(problem.to_string()),
        };
        match decode_link_message::<RunnerMessage>(&frame) {
            Ok(RunnerMessage::Events { events }) => {
                append_events(&table, run_id, events);
            }
            Ok(RunnerMessage::Accepted) => {}
            Ok(RunnerMessage::Refused { reason }) => break Some(reason),
            Ok(RunnerMessage::Answered { .. }) => {
                break Some(FILES_DURING_WATCH.to_owned());
            }
            Err(problem) => break Some(problem.to_string()),
        }
    };
    let mut locked_table = lock_table(&table);
    if let Some(state) = locked_table.get_mut(&run_id) {
        state.lose_link(ending_problem);
    }
}

fn append_events(table: &WatchTable, run_id: RunId, events: Vec<RunEvent>) {
    let mut locked_table = lock_table(table);
    if let Some(state) = locked_table.get_mut(&run_id) {
        state.undelivered.extend(events);
    }
}

fn lock_table(
    table: &WatchTable,
) -> MutexGuard<'_, BTreeMap<RunId, WatchState>> {
    table.lock().unwrap_or_else(PoisonError::into_inner)
}
