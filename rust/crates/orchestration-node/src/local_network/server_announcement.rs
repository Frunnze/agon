use std::fmt;
use std::time::Duration;

use mdns_sd::{ServiceDaemon, ServiceInfo};

use super::{
    APP_SERVER_SERVICE_TYPE, SERVER_ADDRESS_PROPERTY,
    describe_local_network_problem,
};
use crate::node_error::NodeError;
use crate::server_address::ServerAddress;

const INSTANCE_NAME_PREFIX: &str = "agents-orchestration-";
const HOST_NAME_SUFFIX: &str = ".local.";
const GOODBYE_LIMIT: Duration = Duration::from_secs(1);

pub(crate) struct ServerAnnouncement {
    daemon: ServiceDaemon,
    service_name: String,
}

impl ServerAnnouncement {
    pub(crate) fn start(
        server_identifier: &str,
        server_address: &ServerAddress,
        peer_port: u16,
    ) -> Result<Self, NodeError> {
        let instance_name =
            format!("{INSTANCE_NAME_PREFIX}{server_identifier}");
        let host_name = format!("{instance_name}{HOST_NAME_SUFFIX}");
        let announced_address =
            server_address.without_direct_addresses().to_string();
        let properties =
            [(SERVER_ADDRESS_PROPERTY, announced_address.as_str())];
        let service = ServiceInfo::new(
            APP_SERVER_SERVICE_TYPE,
            &instance_name,
            &host_name,
            (),
            peer_port,
            &properties[..],
        )
        .map_err(|problem| describe_local_network_problem(&problem))?
        .enable_addr_auto();

        let service_name = service.get_fullname().to_owned();
        let daemon = ServiceDaemon::new()
            .map_err(|problem| describe_local_network_problem(&problem))?;
        if let Err(problem) = daemon.register(service) {
            let _stopping = daemon.shutdown();
            return Err(describe_local_network_problem(&problem));
        }
        Ok(Self {
            daemon,
            service_name,
        })
    }

    pub(crate) fn stop(&self) {
        if let Ok(unregistering) = self.daemon.unregister(&self.service_name) {
            let _goodbye_sent = unregistering.recv_timeout(GOODBYE_LIMIT);
        }
        let _stopping = self.daemon.shutdown();
    }
}

impl fmt::Debug for ServerAnnouncement {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter
            .debug_struct("ServerAnnouncement")
            .field("service_name", &self.service_name)
            .finish_non_exhaustive()
    }
}
