use serde_json::Value;

use crate::pairing_desk::{
    PairingAction, PairingDevice, cancel_pairing, read_status_problem,
    start_pairing,
};

#[derive(Debug)]
pub struct PairingObservation {
    pub action: PairingAction,
    pub started_session: Option<Value>,
    pub status_problem_before: Value,
    pub status_problem_after: Value,
}

pub fn observe_pairing_actions(
    device: &dyn PairingDevice,
    actions: &[PairingAction],
) -> Result<Vec<PairingObservation>, String> {
    let mut showing_session: Option<Value> = None;
    let mut observations = Vec::new();
    for action in actions {
        let status_problem_before = read_status_problem(device)?;
        let started_session = match action {
            PairingAction::Start => Some(start_pairing(device)?),
            PairingAction::CancelLatest => {
                if let Some(session) = showing_session.take() {
                    cancel_pairing(device, &session)?;
                }
                None
            }
        };
        if let Some(session) = &started_session {
            showing_session = Some(session.clone());
        }

        observations.push(PairingObservation {
            action: *action,
            started_session,
            status_problem_before,
            status_problem_after: read_status_problem(device)?,
        });
    }
    Ok(observations)
}
