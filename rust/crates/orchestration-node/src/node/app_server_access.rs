use std::sync::{Arc, PoisonError, RwLockWriteGuard};

use orchestration_api::server_group::ServerGroupView;
use orchestration_core::server_group::ServerGroup;

use super::{DeviceSession, Node};
#[cfg(feature = "app-server")]
use crate::app_server_hosting::HostedAppServer;
use crate::device_files::{AppServerRecord, DeviceFiles};
use crate::node_error::NodeError;
use crate::server_address::ServerAddress;
use crate::server_client::{PeerDialer, ServerClient};
use crate::server_group_check::check_server_group;
use crate::server_order::{OwnServerRoute, order_server_addresses};

impl Node {
    pub fn app_server(&self) -> Result<ServerClient, NodeError> {
        let app_server = self
            .app_server
            .read()
            .unwrap_or_else(PoisonError::into_inner);
        app_server.clone().ok_or(NodeError::NoAppServer)
    }

    pub fn connect_to_server(
        &self,
        address: &ServerAddress,
    ) -> Result<ServerClient, NodeError> {
        ServerClient::connect(address, &self.server_dialer)
    }

    pub fn remember_app_server(
        &self,
        server: &ServerClient,
    ) -> Result<(), NodeError> {
        let record = AppServerRecord {
            server_address: server.address().to_string(),
        };
        self.device_files.save_app_server(&record)?;
        self.reconnect_app_server()
    }

    pub fn remember_server_group(
        &self,
        server_group: &ServerGroup,
    ) -> Result<(), NodeError> {
        check_server_group(server_group)?;
        let stored_group = self.device_files.load_server_group()?;
        if stored_group.as_ref() == Some(server_group) {
            return Ok(());
        }
        self.device_files.save_server_group(server_group)?;
        self.reconnect_app_server()
    }

    pub async fn refresh_server_group(
        &self,
        session: &DeviceSession,
    ) -> Result<ServerGroupView, NodeError> {
        let view = session.client().read_server_group().await?;
        self.remember_server_group(&view.group)?;
        Ok(view)
    }

    pub(crate) fn reconnect_app_server(&self) -> Result<(), NodeError> {
        let own_server = describe_own_server_route(self);
        let app_server = connect_recorded_server(
            &self.device_files,
            &self.server_dialer,
            own_server.as_ref(),
        )?;
        *self.write_app_server() = app_server;
        Ok(())
    }

    pub(super) fn write_app_server(
        &self,
    ) -> RwLockWriteGuard<'_, Option<ServerClient>> {
        self.app_server
            .write()
            .unwrap_or_else(PoisonError::into_inner)
    }
}

pub(super) fn connect_recorded_server(
    device_files: &DeviceFiles,
    dialer: &Arc<PeerDialer>,
    own_server: Option<&OwnServerRoute>,
) -> Result<Option<ServerClient>, NodeError> {
    let Some(record) = device_files.load_app_server()? else {
        return Ok(None);
    };
    let primary = ServerAddress::parse(&record.server_address)?;
    let server_group = device_files.load_server_group()?;
    let ordered =
        order_server_addresses(&primary, server_group.as_ref(), own_server);
    let client = ServerClient::connect_in_order(&primary, &ordered, dialer)?;
    Ok(Some(client))
}

#[cfg(feature = "app-server")]
fn describe_own_server_route(node: &Node) -> Option<OwnServerRoute> {
    let hosted_slot = node.lock_hosted_app_server();
    hosted_slot.as_ref().map(HostedAppServer::own_route)
}

#[cfg(not(feature = "app-server"))]
fn describe_own_server_route(_node: &Node) -> Option<OwnServerRoute> {
    None
}
