use std::collections::BTreeMap;

use orchestration_core::agent_place::{AgentPlace, find_sandbox_place};
use orchestration_core::device::SandboxKind;
use orchestration_runner::agent_sandbox::AgentSandbox;
use orchestration_runner::sandbox_choice::choose_sandbox;
use proptest::collection::vec;
use proptest::prelude::*;

use crate::fake_agent::test_container;

const MAXIMUM_SANDBOXES: usize = 4;

fn any_sandbox() -> impl Strategy<Value = AgentSandbox> {
    let kinds = vec![
        SandboxKind::LocalProcess,
        SandboxKind::Container,
        SandboxKind::MicroVirtualMachine,
    ];
    (
        proptest::sample::select(kinds),
        vec("[a-z]{1,8}\\.com", 0..2),
    )
        .prop_map(|(kind, allowed_hosts)| AgentSandbox {
            kind,
            container: test_container(),
            allowed_hosts,
            environment: BTreeMap::new(),
        })
}

fn any_place() -> impl Strategy<Value = AgentPlace> {
    prop_oneof![Just(AgentPlace::Container), Just(AgentPlace::LocalProcess)]
}

fn offers_place(sandboxes: &[AgentSandbox], wanted: AgentPlace) -> bool {
    sandboxes
        .iter()
        .any(|sandbox| find_sandbox_place(sandbox.kind) == Some(wanted))
}

proptest! {
    #[test]
    fn test_choose_sandbox_property_a_wanted_place_gets_that_place_or_none(
        sandboxes in vec(any_sandbox(), 0..MAXIMUM_SANDBOXES),
        wanted in any_place(),
    ) {
        let chosen = choose_sandbox(&sandboxes, Some(wanted));

        prop_assert_eq!(chosen.is_some(), offers_place(&sandboxes, wanted));
        if let Some(sandbox) = chosen {
            prop_assert_eq!(find_sandbox_place(sandbox.kind), Some(wanted));
        }
    }

    #[test]
    fn test_choose_sandbox_property_no_wanted_place_takes_the_first(
        sandboxes in vec(any_sandbox(), 0..MAXIMUM_SANDBOXES),
    ) {
        let chosen = choose_sandbox(&sandboxes, None);

        prop_assert_eq!(chosen, sandboxes.first());
    }
}
