use orchestration_core::local_folders::LocalFolderProblem;
use orchestration_core::naming::NameProblem;
use orchestration_core::protected_files::ProtectedPatternProblem;
use orchestration_core::repository_address::AddressProblem;
use orchestration_core::repository_paths::RepositoryPathProblem;
use orchestration_core::rule_titles::RuleTitleProblem;
use orchestration_core::schedule_rules::ScheduleProblem;
use orchestration_core::workflow_graph::WorkflowProblem;
use orchestration_p2p::peer_error::PeerError;
use orchestration_security::error::SecurityError;
use thiserror::Error;
use uuid::Uuid;

use crate::identity_store::IdentityStoreError;

#[derive(Debug, Error)]
pub enum NodeError {
    #[error(transparent)]
    Security(#[from] SecurityError),
    #[error(transparent)]
    IdentityStore(#[from] IdentityStoreError),
    #[error("could not use the data directory: {0}")]
    Storage(#[from] std::io::Error),
    #[error("could not encode or decode JSON: {0}")]
    Json(#[from] serde_json::Error),
    #[error(transparent)]
    Name(#[from] NameProblem),
    #[error(transparent)]
    ProtectedPattern(#[from] ProtectedPatternProblem),
    #[error(transparent)]
    RepositoryAddress(#[from] AddressProblem),
    #[error(transparent)]
    Schedule(#[from] ScheduleProblem),
    #[error(transparent)]
    RepositoryPath(#[from] RepositoryPathProblem),
    #[error(transparent)]
    RuleTitle(#[from] RuleTitleProblem),
    #[error(transparent)]
    LocalFolder(#[from] LocalFolderProblem),
    #[error("the folder {0} does not exist or this app cannot open it")]
    FolderMissing(String),
    #[error("the folder {0} already exists, so choose another name or place")]
    FolderExists(String),
    #[error("the folder {0} is not a git repository")]
    NotGitRepository(String),
    #[error("the folder {0} has no branch checked out")]
    NoCheckedOutBranch(String),
    #[error("could not start git in the folder {folder}: {problem}")]
    GitNotStarted { folder: String, problem: String },
    #[error("the folder {0} is on another computer, so add it there")]
    FolderOnAnotherDevice(String),
    #[error("only a project draft takes chosen folders, not a {0}")]
    FoldersOutsideProject(&'static str),
    #[error(transparent)]
    Workflow(#[from] WorkflowProblem),
    #[error("the node could not start: {0}")]
    Startup(String),
    #[error("the server address {0} is not an http, https or peer address")]
    InvalidServerAddress(String),
    #[error("could not reach the app server: {0}")]
    ServerUnreachable(String),
    #[error("the app server answered {status}: {message}")]
    ServerRejected { status: u16, message: String },
    #[error("the app server sent an unexpected answer: {0}")]
    UnexpectedAnswer(String),
    #[error("{0:?} cannot be used inside a route")]
    InvalidRouteValue(String),
    #[error("the route {0} still has a placeholder without a value")]
    MissingRouteValue(String),
    #[error(
        "could not delete the device identity, nothing was forgotten: {0}"
    )]
    IdentityNotForgotten(IdentityStoreError),
    #[error("this device has no app server yet")]
    NoAppServer,
    #[error("this device has no account yet")]
    NoAccount,
    #[error("this device already has an account")]
    AccountExists,
    #[error("no pairing request from this device is waiting")]
    NoPendingJoin,
    #[error("nobody has entered the pairing code yet")]
    NoJoiningDevice,
    #[error("this device did not show the pairing code, start again")]
    PairingNotStartedHere,
    #[error("the joining device has not sent its pairing nonce yet")]
    PairingWordsNotReady,
    #[error("the app server changed the joining device after the words")]
    PairingTranscriptChanged,
    #[error("this device holds no key for workspace {0}")]
    MissingWorkspaceKey(Uuid),
    #[error("the sealed text cannot be opened with any workspace key")]
    UnreadableSealedText,
    #[error("{kind} {identifier} was not found")]
    NotFound {
        kind: &'static str,
        identifier: String,
    },
    #[error("project {project} is not part of workspace {workspace}")]
    ProjectOutsideWorkspace { project: Uuid, workspace: Uuid },
    #[error("the {field} cannot be empty")]
    EmptyText { field: &'static str },
    #[error("the answer names none of the choices: {}", .choices.join(", "))]
    UnmatchedAnswer { choices: Vec<String> },
    #[error("a command must be a JSON object with a command name: {0}")]
    InvalidCommand(String),
    #[error("unknown command: {0}")]
    UnknownCommand(String),
    #[error("invalid arguments for {command}: {problem}")]
    InvalidArguments { command: String, problem: String },
    #[error("the approval decision cannot be trusted: {0}")]
    UntrustedDecision(String),
    #[error("the drafting agent did not answer with a workflow: {0}")]
    DraftNotWorkflow(String),
    #[error("the drafting agent answered without a message")]
    DraftWithoutAnswer,
    #[error("the drafting agent wrote workflow {found}, not {expected}")]
    DraftForAnotherWorkflow { expected: Uuid, found: Uuid },
    #[error("the drafting run did not finish: {0}")]
    DraftFailed(String),
    #[error("the drafting agent did not answer with a {kind}: {problem}")]
    DraftNotItem { kind: &'static str, problem: String },
    #[error("this device cannot run tasks")]
    RunnerUnavailable,
    #[error("a runner offers at least one place for agents to run")]
    NoAgentOffers,
    #[error("the token or API key cannot have spaces or line breaks")]
    InvalidAgentSecret,
    #[error("a Claude Code login is already open")]
    AgentLoginOpen,
    #[error("no Claude Code login is open")]
    NoAgentLogin,
    #[error("Claude Code could not report its login: {0}")]
    ClaudeStatusUnreadable(String),
    #[error("the Claude Code login terminal failed: {0}")]
    LoginTerminal(String),
    #[error("this node has no peer endpoint")]
    NoPeerEndpoint,
    #[error("the peer link failed: {0}")]
    PeerLink(#[from] PeerError),
    #[error("device {0} has published no trusted peer address")]
    UntrustedPeerAddress(String),
    #[error("the peer is not a trusted client of this run's workspace")]
    UntrustedPeer,
    #[error("no runner is working on this run right now")]
    NoActiveRunner,
    #[error("the runner refused the live link: {0}")]
    LinkRefused(String),
    #[error("the live link message could not be read: {0}")]
    MalformedLinkMessage(String),
    #[error("the runner did not answer the live link in time")]
    LinkTimedOut,
    #[error("the peer is not a trusted client of this project's workspace")]
    UntrustedFileReader,
    #[error("the repository {0} is not part of the project")]
    RepositoryOutsideProject(String),
    #[error("the runner could not read the repository: {0}")]
    RepositoryRead(String),
    #[error("the runner refused to show the files: {0}")]
    FilesRefused(String),
    #[error("this device cannot host the app server")]
    HostingUnavailable,
    #[error("the app server cannot listen on port {port}: {problem}")]
    AppServerPortUnavailable { port: u16, problem: String },
    #[error("the app server on this device failed: {0}")]
    HostedServerFailed(String),
    #[error("the app server on this device already has an account")]
    HostedServerHasAccount,
    #[error("the local network service failed: {0}")]
    LocalNetwork(String),
    #[error("no app server accepted the code")]
    NoServerAcceptedCode,
    #[error("the code could not be published or looked up: {0}")]
    Rendezvous(PeerError),
    #[error("the published record for the code is malformed: {0}")]
    MalformedRendezvousRecord(String),
    #[error("the app server on this device could not be removed: {0}")]
    HostedServerNotRemoved(String),
    #[error("only a client device can keep a backup of the app server")]
    BackupNeedsClient,
    #[error("this device already keeps the app server")]
    AlreadyKeepingServer,
    #[error("the app server keeps no backups")]
    ServerKeepsNoBackups,
    #[error("this device is the active app server")]
    ActiveServerCannotStop,
    #[error("this device keeps no app server")]
    NotKeepingServer,
    #[error("the active app server sent no copy of its state")]
    NoServerCopy,
    #[error("this device no longer keeps the app server")]
    RemovedFromServerGroup,
    #[error("the app server sent a malformed server group: {0}")]
    MalformedServerGroup(&'static str),
}
