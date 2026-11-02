use proptest::collection::vec;
use proptest::prelude::*;

use crate::writer_simulation::{
    NODE_COUNT, Simulation, count_active, restart_node, run_tick,
    start_simulation,
};

const MOST_EVENTS: usize = 30;
const SETTLING_TICKS: usize = 20;
const SCHEDULE_CASES: u32 = 12;

#[derive(Clone, Copy, Debug)]
enum ScheduleEvent {
    Tick,
    StopOrStart(usize),
    CutOrHeal(usize, usize),
}

fn event_strategy() -> impl Strategy<Value = ScheduleEvent> {
    prop_oneof![
        3 => Just(ScheduleEvent::Tick),
        1 => (0..NODE_COUNT).prop_map(ScheduleEvent::StopOrStart),
        1 => (0..NODE_COUNT, 0..NODE_COUNT)
            .prop_map(|(first, second)| {
                ScheduleEvent::CutOrHeal(first, second)
            }),
    ]
}

fn apply_event(
    simulation: &mut Simulation,
    event: ScheduleEvent,
) -> Result<(), String> {
    match event {
        ScheduleEvent::Tick => run_tick(simulation)?,
        ScheduleEvent::StopOrStart(index) => {
            let node = &mut simulation.nodes[index];
            if node.is_running {
                node.is_running = false;
            } else {
                restart_node(node);
            }
        }
        ScheduleEvent::CutOrHeal(first, second) => {
            let link = (first.min(second), first.max(second));
            if let Some(found) =
                simulation.cut_links.iter().position(|cut| *cut == link)
            {
                simulation.cut_links.remove(found);
            } else {
                simulation.cut_links.push(link);
            }
        }
    }
    Ok(())
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(SCHEDULE_CASES))]

    #[test]
    fn test_take_over_property_two_writers_never_share_a_term(
        events in vec(event_strategy(), 1..MOST_EVENTS),
    ) {
        let mut simulation = start_simulation();
        for node_index in 1..NODE_COUNT {
            let fixture_copy = &simulation.nodes[node_index];
            let source = &simulation.nodes[0];
            let replica = serde_json::to_vec(
                &source.server.server.snapshot_state()?,
            )?;
            fixture_copy
                .server
                .server
                .install_replica(&replica, &source.server.server.device_id())?;
        }

        for event in events {
            apply_event(&mut simulation, event)
                .map_err(TestCaseError::fail)?;
        }
        simulation.cut_links.clear();
        for node in &mut simulation.nodes {
            if !node.is_running {
                restart_node(node);
            }
        }
        for _ in 0..SETTLING_TICKS {
            run_tick(&mut simulation).map_err(TestCaseError::fail)?;
        }

        prop_assert_eq!(count_active(&simulation), 1);
    }
}
