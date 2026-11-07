import 'package:flutter_test/flutter_test.dart';

import '../fakes/support/workspace_work_steps.dart';

const String _typePrefix = 'test_node_backed_job_repository';
const int _sequenceIterations = 25;
const List<WorkRigStep> _jobSteps = <WorkRigStep>[
  createJobInBoth,
  updateJobInBoth,
  deleteJobInBoth,
];

Future<void> _checkJobAgreement(WorkRigStep focus, int seed) {
  return runWorkTwinSequences(
    seed: seed,
    iterations: _sequenceIterations,
    focus: focus,
    others: _jobSteps,
  );
}

void main() {
  test('${_typePrefix}_list_jobs_property_lists_only_the_current_'
      'workspace_like_the_fake', () async {
    await _checkJobAgreement(createJobInBoth, 77101);
  });

  test('${_typePrefix}_fetch_jobs_property_follows_every_workspace_switch_'
      'like_the_fake', () async {
    await _checkJobAgreement(updateJobInBoth, 77102);
  });

  test('${_typePrefix}_create_job_property_refuses_and_lists_like_the_'
      'fake', () async {
    await _checkJobAgreement(createJobInBoth, 77103);
  });

  test('${_typePrefix}_update_job_property_refuses_and_moves_like_the_'
      'fake', () async {
    await _checkJobAgreement(updateJobInBoth, 77104);
  });

  test('${_typePrefix}_delete_job_property_refuses_and_removes_like_the_'
      'fake', () async {
    await _checkJobAgreement(deleteJobInBoth, 77105);
  });

  test('${_typePrefix}_find_job_property_finds_exactly_what_the_fake_'
      'finds', () async {
    await _checkJobAgreement(deleteJobInBoth, 77106);
  });
}
