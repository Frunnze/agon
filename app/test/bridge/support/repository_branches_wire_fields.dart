import 'wire_contract_checks.dart';

const String branchesKindField = 'kind';

const WireFields availableBranchesFields = WireFields(
  requiredFields: <String>[
    branchesKindField,
    'runner',
    'branches',
    'task_branches',
  ],
  optionalFields: <String>[],
  defaultedListFields: <String>[],
);

const WireFields unavailableBranchesFields = WireFields(
  requiredFields: <String>[branchesKindField, 'holders'],
  optionalFields: <String>[],
  defaultedListFields: <String>[],
);
