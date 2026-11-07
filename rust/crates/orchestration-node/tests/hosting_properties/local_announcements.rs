use std::fmt;
use std::time::{Duration, Instant};

use mdns_sd::{Receiver, ServiceDaemon, ServiceEvent};
use orchestration_core::peer_address::PeerAddress;
use orchestration_node::server_address::ServerAddress;

use crate::support::test_device::describe;
use crate::support::waiting::wait_for;

const APP_SERVER_SERVICE_TYPE: &str = "_agentorch._tcp.local.";
const SERVER_ADDRESS_PROPERTY: &str = "server_address";
const SEARCH_LIMIT: Duration = Duration::from_secs(30);
const ATTEMPT_LIMIT: Duration = Duration::from_secs(10);
const ANNOUNCEMENT_LIMIT: Duration = Duration::from_secs(90);
const ANNOUNCEMENT_DESCRIPTION: &str = "the server to be announced";
const NOT_ANNOUNCED: &str = "the server was not announced in time";
const NOT_WITHDRAWN: &str = "the announcement was not withdrawn in time";

#[derive(Debug)]
pub struct ResolvedAnnouncement {
    pub full_name: String,
    pub port: u16,
}

pub struct AnnouncementWatch {
    daemon: ServiceDaemon,
    events: Receiver<ServiceEvent>,
}

pub fn describe_announced_address(peer_address: &PeerAddress) -> String {
    let address = ServerAddress::Peer(peer_address.clone());
    address.without_direct_addresses().to_string()
}

pub fn watch_for_announcement(
    wanted_address: &str,
) -> Result<(AnnouncementWatch, ResolvedAnnouncement), String> {
    wait_for(ANNOUNCEMENT_LIMIT, ANNOUNCEMENT_DESCRIPTION, || {
        let watch = AnnouncementWatch::start()?;
        match watch.wait_for_announcement(wanted_address) {
            Ok(announced) => Ok(Some((watch, announced))),
            Err(problem) if problem == NOT_ANNOUNCED => Ok(None),
            Err(problem) => Err(problem),
        }
    })
}

impl AnnouncementWatch {
    fn start() -> Result<Self, String> {
        let daemon = ServiceDaemon::new().map_err(describe)?;
        let events =
            daemon.browse(APP_SERVER_SERVICE_TYPE).map_err(describe)?;
        Ok(Self { daemon, events })
    }

    fn wait_for_announcement(
        &self,
        wanted_address: &str,
    ) -> Result<ResolvedAnnouncement, String> {
        let deadline = Instant::now() + ATTEMPT_LIMIT;
        loop {
            let remaining = deadline.saturating_duration_since(Instant::now());
            let event = self
                .events
                .recv_timeout(remaining)
                .map_err(|_| NOT_ANNOUNCED.to_owned())?;
            let ServiceEvent::ServiceResolved(service) = event else {
                continue;
            };
            let announced =
                service.get_property_val_str(SERVER_ADDRESS_PROPERTY);
            if announced == Some(wanted_address) {
                return Ok(ResolvedAnnouncement {
                    full_name: service.get_fullname().to_owned(),
                    port: service.get_port(),
                });
            }
        }
    }

    pub fn wait_for_withdrawal(&self, full_name: &str) -> Result<(), String> {
        let deadline = Instant::now() + SEARCH_LIMIT;
        loop {
            let remaining = deadline.saturating_duration_since(Instant::now());
            let event = self
                .events
                .recv_timeout(remaining)
                .map_err(|_| NOT_WITHDRAWN.to_owned())?;
            let ServiceEvent::ServiceRemoved(_, removed_name) = event else {
                continue;
            };
            if removed_name == full_name {
                return Ok(());
            }
        }
    }
}

impl fmt::Debug for AnnouncementWatch {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter
            .debug_struct("AnnouncementWatch")
            .finish_non_exhaustive()
    }
}

impl Drop for AnnouncementWatch {
    fn drop(&mut self) {
        let _stopping = self.daemon.shutdown();
    }
}
