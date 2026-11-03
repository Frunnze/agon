use chrono::{DateTime, Utc, Weekday};
use orchestration_core::agent_place::AgentPlace;
use orchestration_core::approval::ApprovalPolicy;
use orchestration_core::device::{Runner, RunnerLink, RunnerTarget};
use orchestration_core::identifiers::{
    DeviceId, ProjectId, RuleId, TaskId, WorkflowId, WorkspaceId,
};
use orchestration_core::library::Rule;
use orchestration_core::scope::{ProjectScope, Scope, WorkspaceScope};
use orchestration_core::task::{
    Schedule, Task, TaskDoer, TaskPlace, TaskStatus, TimeOfDay,
};
use orchestration_core::workflow::AgentKind;
use proptest::collection::vec;
use proptest::prelude::*;
use uuid::Uuid;

const DISTINCT_IDENTIFIER_COUNT: u128 = 4;
const MAXIMUM_SCOPE_ENTRIES: usize = 4;
const MAXIMUM_LABELS: usize = 4;
const MAXIMUM_SLOTS: u32 = 4;
const LATEST_ORDINARY_TIMESTAMP_SECONDS: i64 = 4_102_444_800;
const NANOSECONDS_PER_SECOND: u32 = 1_000_000_000;
pub const HOURS_PER_DAY: u32 = 24;
pub const MINUTES_PER_HOUR: u32 = 60;

pub fn workspace_identifier() -> impl Strategy<Value = WorkspaceId> {
    (0..DISTINCT_IDENTIFIER_COUNT)
        .prop_map(|number| WorkspaceId(Uuid::from_u128(number)))
}

pub fn project_identifier() -> impl Strategy<Value = ProjectId> {
    (0..DISTINCT_IDENTIFIER_COUNT)
        .prop_map(|number| ProjectId(Uuid::from_u128(number)))
}

pub fn workspace_scope() -> impl Strategy<Value = WorkspaceScope> {
    prop_oneof![
        Just(WorkspaceScope::AllWorkspaces),
        vec(workspace_identifier(), 0..MAXIMUM_SCOPE_ENTRIES).prop_map(
            |workspaces| WorkspaceScope::OnlyWorkspaces { workspaces }
        ),
    ]
}

pub fn project_scope() -> impl Strategy<Value = ProjectScope> {
    prop_oneof![
        Just(ProjectScope::AllProjects),
        vec(project_identifier(), 0..MAXIMUM_SCOPE_ENTRIES)
            .prop_map(|projects| ProjectScope::OnlyProjects { projects }),
    ]
}

pub fn scope() -> impl Strategy<Value = Scope> {
    (workspace_scope(), project_scope()).prop_map(|(workspaces, projects)| {
        Scope {
            workspaces,
            projects,
        }
    })
}

pub fn rule_with_text(
    title: impl Strategy<Value = String>,
    details: impl Strategy<Value = String>,
) -> impl Strategy<Value = Rule> {
    (any::<u128>(), title, details, scope(), any::<bool>()).prop_map(
        |(number, title, details, scope, enabled)| Rule {
            id: RuleId(Uuid::from_u128(number)),
            title,
            details,
            scope,
            enabled,
            added_at: DateTime::UNIX_EPOCH,
        },
    )
}

pub fn device_identifier() -> impl Strategy<Value = DeviceId> {
    "[a-c]{1,2}".prop_map(DeviceId)
}

pub fn label() -> impl Strategy<Value = String> {
    prop_oneof![
        Just("gpu".to_owned()),
        Just("mac".to_owned()),
        Just("linux".to_owned()),
    ]
}

pub fn runner_target() -> impl Strategy<Value = RunnerTarget> {
    prop_oneof![
        Just(RunnerTarget::AnyFreeRunner),
        device_identifier()
            .prop_map(|device_id| RunnerTarget::SpecificRunner { device_id }),
        vec(label(), 0..MAXIMUM_LABELS)
            .prop_map(|labels| RunnerTarget::RunnerWithLabels { labels }),
    ]
}

pub fn runner() -> impl Strategy<Value = Runner> {
    (
        device_identifier(),
        vec(label(), 0..MAXIMUM_LABELS),
        0..=MAXIMUM_SLOTS,
        0..=MAXIMUM_SLOTS,
        any::<bool>(),
        any::<bool>(),
    )
        .prop_map(
            |(
                device_id,
                labels,
                slots_total,
                slots_busy,
                online,
                accepting_new_runs,
            )| Runner {
                device_id,
                labels,
                slots_total,
                slots_busy,
                link: RunnerLink::Direct,
                online,
                accepting_new_runs,
                offers: vec![AgentPlace::Container],
                allowed_hosts: Vec::new(),
                cached_repositories: Vec::new(),
            },
        )
}

pub fn available_runner() -> impl Strategy<Value = Runner> {
    (runner(), 1..=MAXIMUM_SLOTS, 0..MAXIMUM_SLOTS).prop_map(
        |(runner, slots_total, busy_seed)| Runner {
            slots_total,
            slots_busy: busy_seed % slots_total,
            online: true,
            accepting_new_runs: true,
            ..runner
        },
    )
}

pub fn agent_place() -> impl Strategy<Value = AgentPlace> {
    prop_oneof![Just(AgentPlace::Container), Just(AgentPlace::LocalProcess)]
}

pub fn agent_kind() -> impl Strategy<Value = AgentKind> {
    prop_oneof![
        Just(AgentKind::ClaudeCode),
        Just(AgentKind::Codex),
        Just(AgentKind::GeminiCli),
    ]
}

pub fn task_status() -> impl Strategy<Value = TaskStatus> {
    prop_oneof![
        Just(TaskStatus::ToDo),
        Just(TaskStatus::Running),
        Just(TaskStatus::WaitingForApproval),
        Just(TaskStatus::Failed),
        Just(TaskStatus::Done),
    ]
}

pub fn example_task() -> Task {
    Task {
        id: TaskId(Uuid::nil()),
        title: "Ship release".to_owned(),
        details: String::new(),
        place: TaskPlace::InProject {
            project_id: ProjectId(Uuid::nil()),
        },
        doer: TaskDoer::OneAgent {
            agent: AgentKind::ClaudeCode,
        },
        runs_on: RunnerTarget::AnyFreeRunner,
        agent_place: Some(AgentPlace::LocalProcess),
        skills: Vec::new(),
        uses_automatic_skills: false,
        approval_policy: ApprovalPolicy::NeverAsk,
        schedule: None,
        status: TaskStatus::ToDo,
        created_at: DateTime::UNIX_EPOCH,
    }
}

pub fn task_with_doer(
    doer: impl Strategy<Value = TaskDoer>,
) -> impl Strategy<Value = Task> {
    (any::<u128>(), doer, task_status()).prop_map(|(number, doer, status)| {
        Task {
            id: TaskId(Uuid::from_u128(number)),
            doer,
            status,
            ..example_task()
        }
    })
}

pub fn one_agent_doer() -> impl Strategy<Value = TaskDoer> {
    agent_kind().prop_map(|agent| TaskDoer::OneAgent { agent })
}

pub fn workflow_doer(
    workflow_id: WorkflowId,
) -> impl Strategy<Value = TaskDoer> {
    Just(TaskDoer::Workflow { workflow_id })
}

pub fn weekday() -> impl Strategy<Value = Weekday> {
    prop_oneof![
        Just(Weekday::Mon),
        Just(Weekday::Tue),
        Just(Weekday::Wed),
        Just(Weekday::Thu),
        Just(Weekday::Fri),
        Just(Weekday::Sat),
        Just(Weekday::Sun),
    ]
}

pub fn valid_time_of_day() -> impl Strategy<Value = TimeOfDay> {
    (0..HOURS_PER_DAY, 0..MINUTES_PER_HOUR)
        .prop_map(|(hour, minute)| TimeOfDay { hour, minute })
}

pub fn valid_schedule() -> impl Strategy<Value = Schedule> {
    prop_oneof![
        (0..MINUTES_PER_HOUR).prop_map(|minute| Schedule::Hour { minute }),
        valid_time_of_day().prop_map(|at| Schedule::Day { at }),
        (weekday(), valid_time_of_day())
            .prop_map(|(on, at)| Schedule::Week { on, at }),
    ]
}

pub fn arbitrary_schedule() -> impl Strategy<Value = Schedule> {
    let any_time = (any::<u32>(), any::<u32>())
        .prop_map(|(hour, minute)| TimeOfDay { hour, minute });
    prop_oneof![
        any::<u32>().prop_map(|minute| Schedule::Hour { minute }),
        any_time.clone().prop_map(|at| Schedule::Day { at }),
        (weekday(), any_time).prop_map(|(on, at)| Schedule::Week { on, at }),
    ]
}

pub fn ordinary_timestamp() -> impl Strategy<Value = DateTime<Utc>> {
    (
        0..LATEST_ORDINARY_TIMESTAMP_SECONDS,
        0..NANOSECONDS_PER_SECOND,
    )
        .prop_filter_map(
            "timestamp in range",
            |(seconds, nanoseconds)| {
                DateTime::from_timestamp(seconds, nanoseconds)
            },
        )
}

pub fn any_supported_timestamp() -> impl Strategy<Value = DateTime<Utc>> {
    let earliest = DateTime::<Utc>::MIN_UTC.timestamp();
    let latest = DateTime::<Utc>::MAX_UTC.timestamp();
    (earliest..=latest, 0..NANOSECONDS_PER_SECOND).prop_filter_map(
        "timestamp in range",
        |(seconds, nanoseconds)| {
            DateTime::from_timestamp(seconds, nanoseconds)
        },
    )
}
