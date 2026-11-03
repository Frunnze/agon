use orchestration_runner::step_outcome::{
    OutcomeProblem, compose_outcome_request, read_reported_outcome,
};
use proptest::collection::btree_set;
use proptest::prelude::*;

fn any_choices() -> impl Strategy<Value = Vec<String>> {
    btree_set("[a-z][a-z0-9 -]{0,10}[a-z]", 1..5)
        .prop_map(|choices| choices.into_iter().collect())
}

proptest! {
    #[test]
    fn test_compose_outcome_request_property_names_every_choice(
        choices in any_choices(),
    ) {
        let request = compose_outcome_request(&choices);

        prop_assert!(request.contains("OUTCOME: <name>"));
        let listed = format!("one of: {}", choices.join(", "));
        prop_assert!(request.contains(&listed), "{}", request);
    }

    #[test]
    fn test_read_reported_outcome_property_reads_the_last_outcome_line(
        choices in any_choices(),
        earlier in any::<prop::sample::Index>(),
        chosen in any::<prop::sample::Index>(),
        label in prop_oneof![
            Just("OUTCOME:"),
            Just("outcome:"),
            Just("Outcome:"),
        ],
        padding in "[ \t]{0,3}",
        body in "[A-Za-z .,]{0,60}",
    ) {
        let earlier_choice = &choices[earlier.index(choices.len())];
        let choice = &choices[chosen.index(choices.len())];
        let message = format!(
            "OUTCOME: {earlier_choice}\n{body}\n\
             {padding}{label} {}{padding}\n",
            choice.to_uppercase()
        );

        let outcome = read_reported_outcome(Some(&message), &choices);

        prop_assert_eq!(outcome, Ok(choice.clone()));
    }

    #[test]
    fn test_read_reported_outcome_property_refuses_a_missing_outcome(
        choices in any_choices(),
        message in proptest::option::of("[A-Za-z .,\n]{0,60}"),
    ) {
        let outcome = read_reported_outcome(message.as_deref(), &choices);

        let problem = OutcomeProblem::Missing { choices: choices.clone() };
        let explanation = problem.to_string();
        prop_assert_eq!(outcome, Err(problem));
        prop_assert!(explanation.contains(&choices.join(", ")));
        prop_assert!(explanation.contains("OUTCOME: <name>"));
    }

    #[test]
    fn test_read_reported_outcome_property_refuses_an_unknown_outcome(
        choices in any_choices(),
        reported in "[0-9]{1,6}",
    ) {
        let message = format!("done\nOUTCOME: {reported}");

        let outcome = read_reported_outcome(Some(&message), &choices);

        let problem = OutcomeProblem::Unknown {
            reported: reported.clone(),
            choices: choices.clone(),
        };
        prop_assert!(problem.to_string().contains(&choices.join(", ")));
        prop_assert_eq!(outcome, Err(problem));
    }
}
