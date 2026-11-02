use chrono::{DateTime, TimeDelta, Utc};
use orchestration_core::approval::{
    ApprovalAction, ApprovalDecision, ApprovalRequest,
};
use orchestration_core::identifiers::{
    ApprovalId, DeviceId, RunId, WorkflowId,
};
use orchestration_security::identity::{IDENTITY_SECRET_LENGTH, KEY_LENGTH};
use proptest::collection::vec;
use proptest::prelude::*;
use uuid::Uuid;

const LATEST_TEST_SECOND: i64 = 4_102_444_800;
const NANOSECONDS_PER_SECOND: u32 = 1_000_000_000;
const MAXIMUM_MESSAGE_LENGTH: usize = 512;
const LONGEST_FUZZ_INPUT: usize = 256;
const MAXIMUM_LIST_LENGTH: usize = 4;
const BITS_PER_BYTE: u8 = 8;
const SHORT_TEXT_PATTERN: &str = "[a-z0-9/-]{1,16}";

pub fn secret_strategy() -> impl Strategy<Value = Vec<u8>> {
    vec(any::<u8>(), IDENTITY_SECRET_LENGTH)
}

pub fn distinct_secrets_strategy() -> impl Strategy<Value = (Vec<u8>, Vec<u8>)>
{
    (secret_strategy(), secret_strategy()).prop_filter(
        "both secret halves must differ",
        |(first, second)| {
            let (first_signing, first_sealing) = first.split_at(KEY_LENGTH);
            let (second_signing, second_sealing) = second.split_at(KEY_LENGTH);
            first_signing != second_signing && first_sealing != second_sealing
        },
    )
}

pub fn message_strategy() -> impl Strategy<Value = Vec<u8>> {
    vec(any::<u8>(), 0..MAXIMUM_MESSAGE_LENGTH)
}

pub fn fuzz_bytes_strategy() -> impl Strategy<Value = Vec<u8>> {
    vec(any::<u8>(), 0..LONGEST_FUZZ_INPUT)
}

pub fn non_empty_message_strategy() -> impl Strategy<Value = Vec<u8>> {
    vec(any::<u8>(), 1..MAXIMUM_MESSAGE_LENGTH)
}

pub fn moment_strategy() -> impl Strategy<Value = DateTime<Utc>> {
    (0..LATEST_TEST_SECOND, 0..NANOSECONDS_PER_SECOND).prop_map(
        |(seconds, nanoseconds)| {
            let whole_seconds = TimeDelta::seconds(seconds);
            let fraction = TimeDelta::nanoseconds(i64::from(nanoseconds));
            DateTime::UNIX_EPOCH + whole_seconds + fraction
        },
    )
}

pub fn decision_strategy() -> impl Strategy<Value = ApprovalDecision> {
    prop_oneof![
        Just(ApprovalDecision::Approved),
        Just(ApprovalDecision::Denied)
    ]
}

pub fn short_text_strategy() -> impl Strategy<Value = String> {
    SHORT_TEXT_PATTERN
}

fn action_strategy() -> impl Strategy<Value = ApprovalAction> {
    prop_oneof![
        (
            short_text_strategy(),
            short_text_strategy(),
            vec(short_text_strategy(), 0..MAXIMUM_LIST_LENGTH)
        )
            .prop_map(|(repository, branch, commits)| {
                ApprovalAction::PushCommits {
                    repository,
                    branch,
                    commits,
                }
            }),
        short_text_strategy()
            .prop_map(|target| ApprovalAction::Deploy { target }),
        (short_text_strategy(), short_text_strategy()).prop_map(
            |(repository, what)| ApprovalAction::DeleteBranchOrFiles {
                repository,
                what,
            }
        ),
        any::<u128>().prop_map(|number| ApprovalAction::SignWorkflow {
            workflow_id: WorkflowId(Uuid::from_u128(number)),
        }),
    ]
}

pub fn approval_request_strategy() -> impl Strategy<Value = ApprovalRequest> {
    (
        any::<u128>(),
        proptest::option::of(any::<u128>()),
        action_strategy(),
        short_text_strategy(),
        moment_strategy(),
    )
        .prop_map(
            |(request_number, run_number, action, requester, moment)| {
                ApprovalRequest {
                    id: ApprovalId(Uuid::from_u128(request_number)),
                    run_id: run_number
                        .map(|number| RunId(Uuid::from_u128(number))),
                    action,
                    requested_by: DeviceId(requester),
                    requested_at: moment,
                    decision: None,
                }
            },
        )
}

pub fn flip_bit(bytes: &[u8], position: usize, bit: u8) -> Vec<u8> {
    let mut flipped = bytes.to_vec();
    let flipped_position = position % flipped.len();
    flipped[flipped_position] ^= 1 << (bit % BITS_PER_BYTE);
    flipped
}
