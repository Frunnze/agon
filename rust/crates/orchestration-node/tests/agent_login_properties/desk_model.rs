use proptest::prelude::*;
use proptest::test_runner::TestCaseError;
use serde_json::Value;

use crate::login_steps::{
    ENTER_KEY, LOGIN_PROMPT, RUNNING_STATE, any_login_code, any_place,
    read_login, start_login, stop_login, type_keys,
};
use crate::support::login_runner::LoginRunner;
use crate::support::test_device::fail;

const MAXIMUM_ACTIONS: usize = 6;

#[derive(Clone, Debug)]
pub enum DeskAction {
    Start(&'static str),
    TypeLine(String),
    TypeUnfinished(String),
    Stop,
    Read,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ModelLogin {
    Absent,
    Running(&'static str),
    Ended(&'static str),
}

impl ModelLogin {
    fn place(self) -> Option<&'static str> {
        match self {
            ModelLogin::Absent => None,
            ModelLogin::Running(place) | ModelLogin::Ended(place) => {
                Some(place)
            }
        }
    }
}

pub fn any_desk_actions() -> impl Strategy<Value = Vec<DeskAction>> {
    let action = prop_oneof![
        2 => any_place().prop_map(DeskAction::Start),
        2 => any_login_code().prop_map(DeskAction::TypeLine),
        1 => any_login_code().prop_map(DeskAction::TypeUnfinished),
        1 => Just(DeskAction::Stop),
        1 => Just(DeskAction::Read),
    ];
    proptest::collection::vec(action, 1..MAXIMUM_ACTIONS)
}

fn run_action(
    nodes: &LoginRunner,
    action: &DeskAction,
) -> Result<Value, String> {
    match action {
        DeskAction::Start(place) => start_login(nodes, place),
        DeskAction::TypeLine(code) => {
            type_keys(nodes, &format!("{code}{ENTER_KEY}"))
        }
        DeskAction::TypeUnfinished(keys) => type_keys(nodes, keys),
        DeskAction::Stop => stop_login(nodes),
        DeskAction::Read => read_login(nodes),
    }
}

fn expect_acceptance(model: ModelLogin, action: &DeskAction) -> bool {
    let is_running = matches!(model, ModelLogin::Running(_));
    match action {
        DeskAction::Start(_) => !is_running,
        DeskAction::TypeLine(_) | DeskAction::TypeUnfinished(_) => is_running,
        DeskAction::Stop | DeskAction::Read => true,
    }
}

fn advance_model(model: ModelLogin, action: &DeskAction) -> ModelLogin {
    match (model, action) {
        (ModelLogin::Running(place), DeskAction::TypeLine(_)) => {
            ModelLogin::Ended(place)
        }
        (ModelLogin::Running(_), DeskAction::Start(_)) => model,
        (_, DeskAction::Start(place)) => ModelLogin::Running(place),
        (_, DeskAction::Stop) => ModelLogin::Absent,
        _ => model,
    }
}

fn settle_after(nodes: &LoginRunner, model: ModelLogin) -> Result<(), String> {
    match model {
        ModelLogin::Running(_) => nodes.wait_for_login_text(LOGIN_PROMPT),
        ModelLogin::Ended(_) => nodes.wait_for_login_end().map(|_| ()),
        ModelLogin::Absent => Ok(()),
    }
}

fn check_view(shown: &Value, model: ModelLogin) -> Result<(), TestCaseError> {
    let Some(expected_place) = model.place() else {
        prop_assert_eq!(shown, &Value::Null);
        return Ok(());
    };
    prop_assert_eq!(&shown["place"], expected_place);
    let is_shown_running = shown["state"] == RUNNING_STATE;
    let is_model_running = matches!(model, ModelLogin::Running(_));
    prop_assert_eq!(is_shown_running, is_model_running, "{}", shown);
    Ok(())
}

pub fn play_against_the_model(
    nodes: &LoginRunner,
    actions: &[DeskAction],
) -> Result<Vec<ModelLogin>, TestCaseError> {
    let mut model = ModelLogin::Absent;
    let mut visited_models = Vec::new();
    for action in actions {
        let reply = run_action(nodes, action);

        let should_accept = expect_acceptance(model, action);
        let is_accepted = reply.is_ok();
        prop_assert_eq!(
            is_accepted,
            should_accept,
            "{:?} {:?}",
            action,
            reply
        );
        model = advance_model(model, action);
        settle_after(nodes, model).map_err(fail)?;
        check_view(&read_login(nodes).map_err(fail)?, model)?;
        visited_models.push(model);
    }
    Ok(visited_models)
}
