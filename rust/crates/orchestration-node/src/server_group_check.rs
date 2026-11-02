use orchestration_core::server_group::ServerGroup;

use crate::node_error::NodeError;

const MEMBERS_WITHOUT_TERM: &str = "its members have no term";
const TERM_WITHOUT_MEMBER: &str =
    "its term names a server that is not a member";
const UNSIGNED_MEMBER_ADDRESS: &str =
    "a member's address does not match its signed key";

pub fn check_server_group(group: &ServerGroup) -> Result<(), NodeError> {
    for member in &group.members {
        if !member.has_signed_address() {
            return Err(NodeError::MalformedServerGroup(
                UNSIGNED_MEMBER_ADDRESS,
            ));
        }
    }

    let Some(term) = &group.term else {
        if group.members.is_empty() {
            return Ok(());
        }
        return Err(NodeError::MalformedServerGroup(MEMBERS_WITHOUT_TERM));
    };
    if group.find_member(&term.server_id).is_none() {
        return Err(NodeError::MalformedServerGroup(TERM_WITHOUT_MEMBER));
    }
    Ok(())
}
