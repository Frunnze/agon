use super::agent_placing::find_settings_place;
use super::image_check::{ImageProbeOutcome, describe_image_problem};
use crate::place_offers::PlaceOffer;
use crate::runner_settings::SandboxSettings;

pub fn check_offers(
    sandboxes: &[SandboxSettings],
    probe: impl Fn(&str, &str) -> ImageProbeOutcome,
) -> Vec<PlaceOffer> {
    let mut checked_offers = Vec::new();
    for sandbox in sandboxes {
        checked_offers.push(PlaceOffer {
            place: find_settings_place(sandbox),
            problem: describe_image_problem(sandbox, &probe),
        });
    }
    checked_offers
}
