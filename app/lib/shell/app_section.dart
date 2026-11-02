import 'package:agent_orchestration/icons/app_icon_kind.dart';

enum AppSection {
  approvals('Approvals', AppIconKind.approval),
  tasks('Tasks', AppIconKind.tasks),
  jobs('Jobs', AppIconKind.jobs),
  projects('Projects', AppIconKind.project),
  workflows('Workflows', AppIconKind.workflow),
  skills('Skills', AppIconKind.skills),
  rules('Rules', AppIconKind.rules),
  settings('Settings', AppIconKind.settings),
  devices('Your devices', AppIconKind.key),
  more('More', AppIconKind.more);

  const AppSection(this.label, this.icon);

  final String label;
  final AppIconKind icon;
}

const List<AppSection> railSections = <AppSection>[
  AppSection.approvals,
  AppSection.tasks,
  AppSection.jobs,
  AppSection.projects,
  AppSection.workflows,
  AppSection.skills,
  AppSection.rules,
  AppSection.settings,
];

const List<AppSection> bottomTabSections = <AppSection>[
  AppSection.approvals,
  AppSection.tasks,
  AppSection.jobs,
  AppSection.projects,
  AppSection.more,
];

AppSection findBottomTabFor(AppSection section) {
  if (bottomTabSections.contains(section)) {
    return section;
  }
  return AppSection.more;
}
