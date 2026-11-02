use orchestration_api::work::RunAssignment;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum RunOutcome {
    Finished,
    Failed,
    Cancelled,
}

pub trait RunExecutor: Send + Sync + 'static {
    fn execute(
        &self,
        assignment: RunAssignment,
    ) -> impl Future<Output = RunOutcome> + Send;
}
