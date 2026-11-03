use orchestration_api::work::{HeartbeatRequest, RunAssignment, TaskStart};
use orchestration_core::agent_place::{AgentPlace, can_take_place};
use orchestration_core::device::{DeviceRole, RunnerTarget};
use orchestration_core::identifiers::DeviceId;
use orchestration_core::task::Task;
use orchestration_security::identity::DeviceIdentity;
use proptest::collection::vec;
use proptest::prelude::*;

use crate::claim_fixtures::{FIRST_RUNNER_SEED, claim};
use crate::fixtures::{
    Account, create_account, create_project, heartbeat_with,
    identity_from_seed, one_agent_task, pair_device, save_task,
    send_heartbeat,
};
use crate::test_client::{TestServer, block_on};

const PLACE_CLAIM_CASES: u32 = 16;
const MAXIMUM_OFFERS: usize = 3;
const MAXIMUM_RUNNERS: usize = 3;
const MAXIMUM_CLAIMS: usize = 8;
const RUNNER_SLOTS: u32 = 2;

fn agent_place() -> impl Strategy<Value = AgentPlace> {
    prop_oneof![Just(AgentPlace::Container), Just(AgentPlace::LocalProcess)]
}

fn offering(offers: &[AgentPlace]) -> HeartbeatRequest {
    HeartbeatRequest {
        offers: offers.to_vec(),
        ..heartbeat_with(&[], RUNNER_SLOTS, 0)
    }
}

async fn pair_offering_runners(
    test: &TestServer,
    account: &Account,
    runner_offers: &[Vec<AgentPlace>],
) -> Vec<DeviceIdentity> {
    let mut runners = Vec::new();
    for (position, offers) in (0_u8..).zip(runner_offers) {
        let identity = identity_from_seed(FIRST_RUNNER_SEED + position);
        let name = format!("runner-{position}");
        let role = DeviceRole::Runner;
        pair_device(test, account, &identity, &name, role).await;
        send_heartbeat(test, &identity, &offering(offers)).await;
        runners.push(identity);
    }
    runners
}

async fn queue_placed_task(
    test: &TestServer,
    account: &Account,
    wanted: Option<AgentPlace>,
) {
    let project = create_project(test, account).await;
    let target = RunnerTarget::AnyFreeRunner;
    let task = Task {
        agent_place: wanted,
        ..one_agent_task(project.id, target, None)
    };
    save_task(test, account, task, TaskStart::Now).await;
}

fn find_offers<'offers>(
    runners: &[DeviceIdentity],
    runner_offers: &'offers [Vec<AgentPlace>],
    runner_id: &DeviceId,
) -> Option<&'offers Vec<AgentPlace>> {
    runners
        .iter()
        .zip(runner_offers)
        .find(|(runner, _offers)| runner.device_id() == *runner_id)
        .map(|(_runner, offers)| offers)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(PLACE_CLAIM_CASES))]

    #[test]
    fn test_claim_next_run_property_a_runner_takes_only_places_it_offers(
        offers in vec(agent_place(), 0..MAXIMUM_OFFERS),
        wanted in proptest::option::of(agent_place()),
    ) {
        let test = TestServer::start();
        let response = block_on(async {
            let account = create_account(&test).await;
            let runner_offers = [offers.clone()];
            let runners =
                pair_offering_runners(&test, &account, &runner_offers).await;
            queue_placed_task(&test, &account, wanted).await;
            claim(&test, &runners[0]).await
        });

        let can_take = can_take_place(&offers, wanted);
        prop_assert_eq!(response.assignment.is_some(), can_take);
    }

    #[test]
    fn test_claim_next_run_property_a_run_never_goes_to_a_runner_without_it(
        runner_offers in vec(
            vec(agent_place(), 0..MAXIMUM_OFFERS),
            1..=MAXIMUM_RUNNERS,
        ),
        wanted in agent_place(),
        claim_order in vec(0_usize..MAXIMUM_RUNNERS, 1..MAXIMUM_CLAIMS),
    ) {
        let test = TestServer::start();
        let (runners, assignments) = block_on(async {
            let account = create_account(&test).await;
            let runners =
                pair_offering_runners(&test, &account, &runner_offers).await;
            queue_placed_task(&test, &account, Some(wanted)).await;
            let mut claimers = Vec::new();
            for runner_position in claim_order {
                claimers.push(&runners[runner_position % runners.len()]);
            }
            claimers.extend(&runners);
            let mut assignments: Vec<RunAssignment> = Vec::new();
            for runner in claimers {
                assignments.extend(claim(&test, runner).await.assignment);
            }
            (runners, assignments)
        });

        let is_offered = runner_offers
            .iter()
            .any(|offers| offers.contains(&wanted));
        prop_assert_eq!(assignments.len(), usize::from(is_offered));
        for assignment in &assignments {
            let no_runner = || TestCaseError::fail("the step has no runner");
            let runner_id =
                assignment.run.steps[0].runner.clone().ok_or_else(no_runner)?;
            let offers = find_offers(&runners, &runner_offers, &runner_id);
            prop_assert!(offers.is_some_and(|offers| offers.contains(&wanted)));
        }
    }

    #[test]
    fn test_receive_heartbeat_property_the_runner_lists_what_it_offers(
        offers in vec(agent_place(), 0..MAXIMUM_OFFERS),
    ) {
        let test = TestServer::start();
        let runner = block_on(async {
            let account = create_account(&test).await;
            let identity = identity_from_seed(FIRST_RUNNER_SEED);
            let role = DeviceRole::Runner;
            pair_device(&test, &account, &identity, "box", role).await;
            send_heartbeat(&test, &identity, &offering(&offers)).await
        });

        prop_assert_eq!(runner.offers, offers);
    }
}
