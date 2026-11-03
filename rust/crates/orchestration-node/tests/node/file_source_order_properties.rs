use chrono::Duration;
use orchestration_core::identifiers::DeviceId;
use orchestration_node::views::{RepositoryHolder, order_file_sources};
use proptest::collection::vec;
use proptest::prelude::*;
use proptest::sample::Index;

use crate::support::entity_strategies::sample_time;

const UNKNOWN_RUNNER_ID: &str = "runner-nobody";
const LONE_OWN_COPY_ID: &str = "runner-this-computer";
const LARGEST_HOLDER_COUNT: usize = 6;

#[derive(Clone, Copy, Debug)]
enum OwnCopyChoice {
    Missing,
    ListedHolder,
    UnlistedComputer,
}

#[derive(Clone, Copy, Debug)]
enum PreferenceChoice {
    Missing,
    ListedHolder,
    OwnCopy,
    UnknownRunner,
}

type CaseSeed = (Vec<bool>, OwnCopyChoice, Index, PreferenceChoice, Index);

#[derive(Debug)]
struct SourceCase {
    holders: Vec<RepositoryHolder>,
    own_copy: Option<RepositoryHolder>,
    preferred_runner_id: Option<DeviceId>,
}

impl SourceCase {
    fn order(&self) -> Vec<DeviceId> {
        let sources = order_file_sources(
            &self.holders,
            self.own_copy.as_ref(),
            self.preferred_runner_id.as_ref(),
        );
        let mut ordered_ids = Vec::new();
        for source in sources {
            ordered_ids.push(source.device_id);
        }
        ordered_ids
    }

    fn own_copy_id(&self) -> Option<&DeviceId> {
        self.own_copy.as_ref().map(|own_copy| &own_copy.device_id)
    }

    fn reachable_ids(&self) -> Vec<DeviceId> {
        let mut reachable_ids = Vec::new();
        if let Some(own_copy_id) = self.own_copy_id() {
            reachable_ids.push(own_copy_id.clone());
        }
        for holder in &self.holders {
            let is_listed = reachable_ids.contains(&holder.device_id);
            if holder.online && !is_listed {
                reachable_ids.push(holder.device_id.clone());
            }
        }
        reachable_ids
    }

    fn is_other_runner(&self, id: &DeviceId) -> bool {
        let is_preferred = self.preferred_runner_id.as_ref() == Some(id);
        let is_own_copy = self.own_copy_id() == Some(id);
        !is_preferred && !is_own_copy
    }

    fn is_preferred_reachable(&self) -> bool {
        let reachable_ids = self.reachable_ids();
        self.preferred_runner_id
            .as_ref()
            .is_some_and(|preferred| reachable_ids.contains(preferred))
    }
}

fn build_holder(index: usize, online: bool) -> RepositoryHolder {
    let minutes = i64::try_from(index).unwrap_or(0);
    RepositoryHolder {
        device_id: DeviceId(format!("runner-{index}")),
        name: format!("computer {index}"),
        last_seen: sample_time() - Duration::minutes(minutes),
        online,
    }
}

fn pick_holder(
    holders: &[RepositoryHolder],
    position: Index,
) -> Option<&RepositoryHolder> {
    if holders.is_empty() {
        return None;
    }
    holders.get(position.index(holders.len()))
}

fn build_own_copy(
    holders: &[RepositoryHolder],
    choice: OwnCopyChoice,
    position: Index,
) -> Option<RepositoryHolder> {
    let lone_own_copy = RepositoryHolder {
        device_id: DeviceId(LONE_OWN_COPY_ID.to_owned()),
        name: "this computer".to_owned(),
        last_seen: sample_time(),
        online: true,
    };
    match choice {
        OwnCopyChoice::Missing => None,
        OwnCopyChoice::UnlistedComputer => Some(lone_own_copy),
        OwnCopyChoice::ListedHolder => {
            let listed = pick_holder(holders, position)?;
            Some(RepositoryHolder {
                online: true,
                ..listed.clone()
            })
        }
    }
}

fn choose_preferred_runner(
    holders: &[RepositoryHolder],
    own_copy: Option<&RepositoryHolder>,
    choice: PreferenceChoice,
    position: Index,
) -> Option<DeviceId> {
    match choice {
        PreferenceChoice::Missing => None,
        PreferenceChoice::UnknownRunner => {
            Some(DeviceId(UNKNOWN_RUNNER_ID.to_owned()))
        }
        PreferenceChoice::OwnCopy => {
            own_copy.map(|own_copy| own_copy.device_id.clone())
        }
        PreferenceChoice::ListedHolder => pick_holder(holders, position)
            .map(|holder| holder.device_id.clone()),
    }
}

fn own_copy_choice() -> impl Strategy<Value = OwnCopyChoice> {
    prop_oneof![
        Just(OwnCopyChoice::Missing),
        Just(OwnCopyChoice::ListedHolder),
        Just(OwnCopyChoice::UnlistedComputer),
    ]
}

fn preference_choice() -> impl Strategy<Value = PreferenceChoice> {
    prop_oneof![
        Just(PreferenceChoice::Missing),
        Just(PreferenceChoice::ListedHolder),
        Just(PreferenceChoice::OwnCopy),
        Just(PreferenceChoice::UnknownRunner),
    ]
}

fn build_case(seed: CaseSeed) -> SourceCase {
    let (online_flags, own_choice, own_position, preference, preferred) = seed;
    let mut holders = Vec::new();
    for (index, online) in online_flags.into_iter().enumerate() {
        holders.push(build_holder(index, online));
    }
    let own_copy = build_own_copy(&holders, own_choice, own_position);
    let preferred_runner_id = choose_preferred_runner(
        &holders,
        own_copy.as_ref(),
        preference,
        preferred,
    );
    SourceCase {
        holders,
        own_copy,
        preferred_runner_id,
    }
}

fn source_case() -> impl Strategy<Value = SourceCase> {
    let online_flags = vec(any::<bool>(), 0..LARGEST_HOLDER_COUNT);
    (
        online_flags,
        own_copy_choice(),
        any::<Index>(),
        preference_choice(),
        any::<Index>(),
    )
        .prop_map(build_case)
}

proptest! {
    #[test]
    fn test_order_file_sources_property_offers_each_reachable_copy_once(
        case in source_case(),
    ) {
        let mut ordered_ids = case.order();
        let mut reachable_ids = case.reachable_ids();

        ordered_ids.sort_by(|first, second| first.0.cmp(&second.0));
        reachable_ids.sort_by(|first, second| first.0.cmp(&second.0));
        prop_assert_eq!(ordered_ids, reachable_ids);
    }

    #[test]
    fn test_order_file_sources_property_puts_a_reachable_preference_first(
        case in source_case(),
    ) {
        let ordered_ids = case.order();

        if case.is_preferred_reachable() {
            prop_assert_eq!(
                ordered_ids.first(),
                case.preferred_runner_id.as_ref()
            );
        }
    }

    #[test]
    fn test_order_file_sources_property_keeps_the_own_copy_before_others(
        case in source_case(),
    ) {
        let ordered_ids = case.order();
        let Some(own_copy_id) = case.own_copy_id() else {
            return Ok(());
        };

        let is_other_preference_first = case.is_preferred_reachable()
            && case.preferred_runner_id.as_ref() != Some(own_copy_id);
        let expected_position = usize::from(is_other_preference_first);
        let own_position =
            ordered_ids.iter().position(|id| id == own_copy_id);
        prop_assert_eq!(own_position, Some(expected_position));
    }

    #[test]
    fn test_order_file_sources_property_keeps_the_latest_seen_runners_first(
        case in source_case(),
    ) {
        let ordered_ids = case.order();

        let mut other_runner_ids = Vec::new();
        for id in &ordered_ids {
            if case.is_other_runner(id) {
                other_runner_ids.push(id.clone());
            }
        }
        let mut online_other_ids = Vec::new();
        for holder in &case.holders {
            let id = &holder.device_id;
            if holder.online && case.is_other_runner(id) {
                online_other_ids.push(id.clone());
            }
        }
        prop_assert_eq!(other_runner_ids, online_other_ids);
    }
}
