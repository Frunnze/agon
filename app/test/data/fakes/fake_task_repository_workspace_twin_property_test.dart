import 'package:flutter_test/flutter_test.dart';

import 'support/workspace_work_rig.dart';
import 'support/workspace_work_steps.dart';

const String _typePrefix = 'test_fake_task_repository';
const int _sequenceIterations = 20;
const List<WorkRigStep> _taskSteps = <WorkRigStep>[
  createTaskInBoth,
  updateTaskInBoth,
  startTaskInBoth,
  deleteTaskInBoth,
  createJobInBoth,
];

Future<void> _checkTaskAgreement(WorkRigStep focus, int seed) {
  return runWorkTwinSequences(
    seed: seed,
    iterations: _sequenceIterations,
    focus: focus,
    others: _taskSteps,
  );
}

void main() {
  test('${_typePrefix}_list_tasks_property_lists_only_the_current_'
      'workspace_like_the_node', () async {
    await _checkTaskAgreement(switchWorkRigWorkspace, 77201);
  });

  test('${_typePrefix}_list_tasks_and_jobs_in_current_workspace_property_'
      'holds_what_the_node_lists', () async {
    await _checkTaskAgreement(createJobInBoth, 77202);
  });

  test('${_typePrefix}_find_task_property_finds_exactly_what_the_node_'
      'finds', () async {
    await _checkTaskAgreement(updateTaskInBoth, 77203);
  });

  test('${_typePrefix}_create_task_property_refuses_outside_projects_like_'
      'the_node', () async {
    await _checkTaskAgreement(createTaskInBoth, 77204);
  });

  test('${_typePrefix}_update_task_property_refuses_and_moves_like_the_'
      'node', () async {
    await _checkTaskAgreement(updateTaskInBoth, 77205);
  });

  test('${_typePrefix}_start_task_property_starts_any_workspace_task_by_id_'
      'like_the_node', () async {
    await _checkTaskAgreement(startTaskInBoth, 77206);
  });

  test('${_typePrefix}_delete_task_property_deletes_any_workspace_task_by_'
      'id_like_the_node', () async {
    await _checkTaskAgreement(deleteTaskInBoth, 77207);
  });

  test('${_typePrefix}_refuse_draft_outside_current_workspace_property_'
      'refuses_exactly_like_the_node', () async {
    await _checkTaskAgreement(createTaskInBoth, 77208);
  });

  test('${_typePrefix}_link_places_property_scopes_every_listing_like_the_'
      'node', () async {
    await _checkTaskAgreement(switchWorkRigWorkspace, 77209);
  });
}
