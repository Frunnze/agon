use chrono::{DateTime, Utc};
use orchestration_api::catalog::WorkflowListing;
use orchestration_core::identifiers::DeviceId;

use crate::stored_state::WorkflowRecord;

#[derive(Clone, Copy, Debug)]
pub struct ChangeStamp<'stamp> {
    pub at: DateTime<Utc>,
    pub by: &'stamp DeviceId,
}

pub fn stamp_change(record: &mut WorkflowRecord, stamp: ChangeStamp<'_>) {
    record.changed_at = Some(stamp.at);
    record.changed_by = Some(stamp.by.clone());
}

#[must_use]
pub fn describe_listing(record: &WorkflowRecord) -> WorkflowListing {
    WorkflowListing {
        workflow: record.current.clone(),
        signed_at: record.signed_at,
        changed_at: record.changed_at,
        changed_by: record.changed_by.clone(),
    }
}
