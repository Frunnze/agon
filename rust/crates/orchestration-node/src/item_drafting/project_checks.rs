use super::draft_checks::CheckedDraft;
use super::drafting_context::DraftingContext;
use super::item_draft::{ItemDraft, ProjectDraft, RepositoryDraft};
use super::problem_sentences::{
    NO_REPOSITORY, describe_taken_project_name, find_name_problem,
};
use super::repository_resolution::resolve_repository;

pub(super) fn check_project_draft(
    context: &DraftingContext,
    project: &ProjectDraft,
) -> CheckedDraft {
    let name = project.name.trim().to_owned();
    let mut problems = Vec::new();
    if let Some(name_problem) = find_project_name_problem(context, &name) {
        problems.push(name_problem);
    }
    if project.repositories.is_empty() {
        problems.push(NO_REPOSITORY.to_owned());
    }

    let mut resolved_repositories: Vec<RepositoryDraft> = Vec::new();
    for answered in &project.repositories {
        match resolve_repository(&context.this_device.id, answered) {
            Ok(resolved) => {
                let is_repeated = resolved_repositories
                    .iter()
                    .any(|earlier| earlier.address == resolved.address);
                if !is_repeated {
                    resolved_repositories.push(resolved);
                }
            }
            Err(problem) => problems.push(problem),
        }
    }

    let draft = ProjectDraft {
        name,
        repositories: resolved_repositories,
        agent_access: project.agent_access,
    };
    CheckedDraft {
        draft: ItemDraft::Project(draft),
        problems,
    }
}

fn find_project_name_problem(
    context: &DraftingContext,
    name: &str,
) -> Option<String> {
    let is_taken = context.projects.iter().any(|project| project.name == name);
    find_name_problem(name)
        .or_else(|| is_taken.then(|| describe_taken_project_name(name)))
}
