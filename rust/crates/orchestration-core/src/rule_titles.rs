use thiserror::Error;

#[derive(Clone, Debug, PartialEq, Eq, Error)]
pub enum RuleTitleProblem {
    #[error("the rule cannot be empty or only spaces, so write the rule")]
    Blank,
}

pub fn validate_rule_title(title: &str) -> Result<(), RuleTitleProblem> {
    if title.trim().is_empty() {
        return Err(RuleTitleProblem::Blank);
    }
    Ok(())
}
