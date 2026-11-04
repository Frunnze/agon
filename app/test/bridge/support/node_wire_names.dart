const List<String> nodeDeviceRoles = <String>[
  'client',
  'runner',
  'client_and_runner',
];

const List<String> nodeHardwareKeyKinds = <String>[
  'secure_enclave',
  'tpm',
  'strong_box',
  'software',
];

const List<String> nodeDeviceKinds = <String>['computer', 'phone'];

const List<String> nodeRunnerLinks = <String>[
  'direct',
  'relay',
  'local_network',
  'unreachable',
];

const List<String> nodeAgentPlaces = <String>['container', 'local_process'];

const List<String> nodeAgentAccesses = <String>[
  'read_only',
  'push_after_approval',
];

const List<String> nodeSkillUsages = <String>['automatic', 'when_chosen'];

const List<String> nodeSkillSources = <String>['built_in', 'created'];

const List<String> nodeSkillImprovements = <String>['never', 'ask_me', 'auto'];

const String nodePersonEditOrigin = 'person_edit';

const List<String> nodeSkillChangeOrigins = <String>[
  nodePersonEditOrigin,
  'approved_agent_run',
  'automatic_agent_run',
];

const List<String> nodeAgentKinds = <String>[
  'claude_code',
  'codex',
  'gemini_cli',
];

const List<String> nodeStepKinds = <String>['agent', 'person'];

const List<String> nodeSignatureStates = <String>[
  'signed',
  'not_signed_yet',
  'changed_not_signed',
];

const List<String> nodeDiffChanges = <String>['unchanged', 'added', 'removed'];

const List<String> nodeTaskStatuses = <String>[
  'to_do',
  'running',
  'waiting_for_approval',
  'failed',
  'done',
];

const List<String> nodeWeekdays = <String>[
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

const List<String> nodeStepStatuses = <String>[
  'waiting',
  'running',
  'waiting_for_approval',
  'waiting_for_person',
  'done',
  'failed',
  'skipped',
];

const List<String> nodeRunStatuses = <String>[
  'queued',
  'running',
  'waiting_for_approval',
  'failed',
  'cancelled',
  'done',
];

const List<String> nodeChatAuthors = <String>['you', 'agent', 'tool'];

const List<String> nodeApprovalPolicies = <String>[
  'ask_before_risky_actions',
  'never_ask',
];

const List<String> nodeApprovalDecisions = <String>['approved', 'denied'];

const List<String> nodeChangeAreas = <String>[
  'account',
  'pairing',
  'devices',
  'workspaces',
  'projects',
  'workflows',
  'skills',
  'rules',
  'tasks',
  'runners',
  'approvals',
  'audit',
  'server_group',
];

const List<String> nodeServerStandings = <String>['active', 'backup'];

const List<String> nodeThisDeviceStandings = <String>[
  'active',
  'backup',
  'none',
];

const List<String> nodeTaskStarts = <String>['now', 'later'];

const List<String> nodeContainerEngines = <String>['docker', 'podman'];

const List<String> nodeRepositoryEntryKinds = <String>[
  'folder',
  'file',
  'link',
];
