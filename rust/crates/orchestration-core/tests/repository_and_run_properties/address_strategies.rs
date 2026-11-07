use proptest::collection::vec;
use proptest::prelude::*;

const MAXIMUM_INNER_HOST_LABELS: usize = 3;
pub const GIT_SUFFIX: &str = ".git";

pub fn host_label() -> impl Strategy<Value = String> {
    "[a-z0-9]([a-z0-9-]{0,6}[a-z0-9])?"
}

pub fn host() -> impl Strategy<Value = String> {
    (
        vec(host_label(), 1..=MAXIMUM_INNER_HOST_LABELS),
        "[a-z]{2,6}",
    )
        .prop_map(|(labels, top_level)| {
            format!("{}.{top_level}", labels.join("."))
        })
}

pub fn path_part() -> impl Strategy<Value = String> {
    "[A-Za-z0-9_][A-Za-z0-9._-]{0,12}"
        .prop_filter("no git suffix", |part| !part.ends_with(GIT_SUFFIX))
}

pub fn canonical_address() -> impl Strategy<Value = String> {
    (host(), path_part(), path_part()).prop_map(|(host, owner, repository)| {
        format!("{host}/{owner}/{repository}")
    })
}
