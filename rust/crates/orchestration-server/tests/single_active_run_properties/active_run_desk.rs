use axum::http::StatusCode;
use orchestration_api::routes::TASKS;
use orchestration_api::work::{SaveTaskRequest, TaskStart};
use orchestration_core::device::RunnerTarget;
use orchestration_core::run::Run;
use orchestration_core::run_lifecycle::is_run_finished;
use orchestration_core::task::{Schedule, Task};
use proptest::prelude::*;

use crate::fixtures::{
    Account, create_account, create_project, one_agent_task, save_task,
};
use crate::test_client::{TestResponse, TestServer, block_on};

pub const ACTION_COUNT_LIMIT: usize = 9;
const CHANGED_TITLE_SUFFIX: &str = " (changed)";

#[derive(Clone, Copy, Debug)]
pub enum RunAction {
    Start,
    SaveAndStart,
    CancelActive,
    Retry { run_choice: usize },
}

#[derive(Debug)]
pub struct ObservedAction {
    pub action: RunAction,
    pub runs_before: Vec<Run>,
    pub task_before: Task,
    pub response: Option<TestResponse>,
    pub runs_after: Vec<Run>,
    pub task_after: Task,
}

#[derive(Debug)]
pub struct ActiveRunDesk {
    pub test: TestServer,
    pub account: Account,
    pub task: Task,
}

pub fn run_action_strategy() -> impl Strategy<Value = RunAction> {
    prop_oneof![
        Just(RunAction::Start),
        Just(RunAction::SaveAndStart),
        Just(RunAction::CancelActive),
        any::<usize>().prop_map(|run_choice| RunAction::Retry { run_choice }),
    ]
}

pub fn run_actions_strategy() -> impl Strategy<Value = Vec<RunAction>> {
    proptest::collection::vec(run_action_strategy(), 1..ACTION_COUNT_LIMIT)
}

#[derive(Clone, Copy, Debug)]
pub enum WorkKind {
    Task,
    Job,
}

impl WorkKind {
    pub fn schedule(self) -> Option<Schedule> {
        match self {
            Self::Task => None,
            Self::Job => Some(Schedule::Hour { minute: 0 }),
        }
    }

    pub fn already_running_message(self) -> String {
        let kind_name = match self {
            Self::Task => "task",
            Self::Job => "job",
        };
        format!("the {kind_name} is already running")
    }
}

pub fn work_kind_strategy() -> impl Strategy<Value = WorkKind> {
    prop_oneof![Just(WorkKind::Task), Just(WorkKind::Job)]
}

pub fn count_active_runs(runs: &[Run]) -> usize {
    let mut active_count = 0;
    for run in runs {
        if !is_run_finished(run.status) {
            active_count += 1;
        }
    }
    active_count
}

pub fn is_accepted(response: &TestResponse) -> bool {
    response.status.is_success()
}

pub fn is_refused_as_running(response: &TestResponse, kind: WorkKind) -> bool {
    response.status == StatusCode::CONFLICT
        && response.error_message() == kind.already_running_message()
}

pub fn open_desk(schedule: Option<Schedule>) -> ActiveRunDesk {
    let test = TestServer::start();
    let (account, task) = block_on(save_desk_task(&test, schedule));
    ActiveRunDesk {
        test,
        account,
        task,
    }
}

async fn save_desk_task(
    test: &TestServer,
    schedule: Option<Schedule>,
) -> (Account, Task) {
    let account = create_account(test).await;
    let project = create_project(test, &account).await;
    let task =
        one_agent_task(project.id, RunnerTarget::AnyFreeRunner, schedule);
    let saved = save_task(test, &account, task, TaskStart::Later).await;
    (account, saved.task)
}

impl ActiveRunDesk {
    pub fn perform_all(&self, actions: &[RunAction]) -> Vec<ObservedAction> {
        block_on(async {
            let mut observed = Vec::new();
            for action in actions {
                observed.push(self.perform(*action).await);
            }
            observed
        })
    }

    pub async fn perform(&self, action: RunAction) -> ObservedAction {
        let runs_before = self.list_runs().await;
        let task_before = self.read_task().await;
        let response = match action {
            RunAction::Start => Some(self.start().await),
            RunAction::SaveAndStart => Some(self.save_and_start().await),
            RunAction::CancelActive => self.cancel_active(&runs_before).await,
            RunAction::Retry { run_choice } => {
                self.retry_chosen(&runs_before, run_choice).await
            }
        };
        ObservedAction {
            action,
            runs_before,
            task_before,
            response,
            runs_after: self.list_runs().await,
            task_after: self.read_task().await,
        }
    }

    pub async fn start(&self) -> TestResponse {
        let path = format!("/tasks/{}/runs", self.task.id.0);
        self.test.post_empty(&self.account.owner, &path).await
    }

    pub async fn save_and_start(&self) -> TestResponse {
        let changed = Task {
            title: format!("{}{CHANGED_TITLE_SUFFIX}", self.task.title),
            ..self.task.clone()
        };
        let request = SaveTaskRequest {
            task: changed,
            start: TaskStart::Now,
        };
        self.test.post(&self.account.owner, TASKS, &request).await
    }

    pub async fn cancel(&self, run: &Run) -> TestResponse {
        let path = format!("/runs/{}/cancel", run.id.0);
        self.test.post_empty(&self.account.owner, &path).await
    }

    pub async fn retry(&self, run: &Run) -> TestResponse {
        let path = format!("/runs/{}/retry", run.id.0);
        self.test.post_empty(&self.account.owner, &path).await
    }

    pub async fn list_runs(&self) -> Vec<Run> {
        let path = format!("/tasks/{}/runs", self.task.id.0);
        let response = self.test.get(&self.account.owner, &path).await;
        let mut runs: Vec<Run> = response.json();
        runs.sort_by_key(|run| run.number);
        runs
    }

    pub async fn read_task(&self) -> Task {
        let tasks: Vec<Task> =
            self.test.get(&self.account.owner, TASKS).await.json();
        tasks
            .into_iter()
            .find(|task| task.id == self.task.id)
            .expect("the desk task stays saved")
    }

    async fn cancel_active(&self, runs: &[Run]) -> Option<TestResponse> {
        let active_run = runs.iter().find(|run| !is_run_finished(run.status));
        match active_run {
            Some(run) => Some(self.cancel(run).await),
            None => None,
        }
    }

    async fn retry_chosen(
        &self,
        runs: &[Run],
        run_choice: usize,
    ) -> Option<TestResponse> {
        if runs.is_empty() {
            return None;
        }
        let chosen_run = &runs[run_choice % runs.len()];
        Some(self.retry(chosen_run).await)
    }
}
