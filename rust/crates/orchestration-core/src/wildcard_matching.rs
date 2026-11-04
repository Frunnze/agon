pub(crate) struct WildcardRules<IsWildcard, MatchesOne> {
    pub(crate) is_wildcard: IsWildcard,
    pub(crate) matches_one: MatchesOne,
}

pub(crate) fn matches_wildcards<Glob, Item, IsWildcard, MatchesOne>(
    globs: &[Glob],
    items: &[Item],
    rules: &WildcardRules<IsWildcard, MatchesOne>,
) -> bool
where
    IsWildcard: Fn(&Glob) -> bool,
    MatchesOne: Fn(&Glob, &Item) -> bool,
{
    let mut glob_index = 0;
    let mut item_index = 0;
    let mut last_wildcard: Option<(usize, usize)> = None;

    while item_index < items.len() {
        let glob = globs.get(glob_index);
        let item = &items[item_index];
        if glob.is_some_and(|glob| (rules.is_wildcard)(glob)) {
            last_wildcard = Some((glob_index + 1, item_index));
            glob_index += 1;
        } else if glob.is_some_and(|glob| (rules.matches_one)(glob, item)) {
            glob_index += 1;
            item_index += 1;
        } else if let Some((after_wildcard, swallowed_until)) = last_wildcard {
            let swallowed_one_more = swallowed_until + 1;
            last_wildcard = Some((after_wildcard, swallowed_one_more));
            glob_index = after_wildcard;
            item_index = swallowed_one_more;
        } else {
            return false;
        }
    }

    let remaining_globs = &globs[glob_index.min(globs.len())..];
    remaining_globs.iter().all(|glob| (rules.is_wildcard)(glob))
}
