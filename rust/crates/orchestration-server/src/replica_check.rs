use orchestration_core::identifiers::DeviceId;
use orchestration_core::server_group::ServerTerm;
use orchestration_security::audit::verify_chain_suffix;

use crate::error::ServerError;
use crate::server_group_trust::check_group;
use crate::stored_state::StoredState;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum TermComparison {
    First,
    Same,
    Higher,
    Lower,
}

pub fn verify_replica(
    current: &StoredState,
    offered: &StoredState,
    source_server_id: &DeviceId,
) -> Result<(), ServerError> {
    check_group(offered)?;
    let offered_term = offered
        .server_group
        .term
        .as_ref()
        .ok_or_else(|| refuse("the copy has no server term"))?;
    if &offered_term.server_id != source_server_id {
        return Err(refuse("the copy does not come from its term's server"));
    }
    keeps_audit_signers(current, offered)?;

    let comparison =
        compare_terms(offered_term, current.server_group.term.as_ref());
    let signers = &offered.server_group.audit_signers;
    let verified_length = match comparison {
        TermComparison::Lower => {
            return Err(refuse("the copy is from an older term"));
        }
        TermComparison::First | TermComparison::Higher => 0,
        TermComparison::Same => {
            if offered.revision <= current.revision {
                return Err(refuse("the copy is not newer"));
            }
            if !offered.audit_log.starts_with(&current.audit_log) {
                return Err(refuse("the copy rewrites the audit log"));
            }
            current.audit_log.len()
        }
    };
    verify_chain_suffix(&offered.audit_log, verified_length, signers)
        .map_err(|problem| refuse(&problem.to_string()))?;
    Ok(())
}

fn compare_terms(
    offered: &ServerTerm,
    current: Option<&ServerTerm>,
) -> TermComparison {
    let Some(current) = current else {
        return TermComparison::First;
    };
    if offered.outranks(current) {
        return TermComparison::Higher;
    }
    if current.outranks(offered) {
        return TermComparison::Lower;
    }
    TermComparison::Same
}

fn keeps_audit_signers(
    current: &StoredState,
    offered: &StoredState,
) -> Result<(), ServerError> {
    let offered_signers = &offered.server_group.audit_signers;
    for (server_id, key) in &current.server_group.audit_signers {
        if offered_signers.get(server_id) != Some(key) {
            return Err(refuse("the copy drops an audit signer"));
        }
    }
    Ok(())
}

fn refuse(reason: &str) -> ServerError {
    ServerError::Conflict(format!("the copy was refused: {reason}"))
}
