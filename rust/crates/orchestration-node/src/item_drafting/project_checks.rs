use super::answer_defaults::pick_form_project_name;
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
    let mut repository_problems = Vec::new();
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
            Err(problem) => repository_problems.push(problem),
        }
    }

    let name = pick_form_project_name(&project.name, &resolved_repositories);
    let mut problems = Vec::new();
    if let Some(name_problem) = find_project_name_problem(context, &name) {
        problems.push(name_problem);
    }
    if project.repositories.is_empty() {
        problems.push(NO_REPOSITORY.to_owned());
    }
    problems.extend(repository_problems);

    let draft = ProjectDraft {
        name,
        repositories: resolved_repositories,
        agent_access: project.agent_access,
        approval_policy: project.approval_policy,
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
