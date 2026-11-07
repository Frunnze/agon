import 'dart:math';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';

import '../../../support/fake_task_work_links.dart';
import '../../../support/random_inputs.dart';
import '../../../support/random_repository_addresses.dart';
import '../../../support/sample_records.dart';
import 'notification_counter.dart';

const List<WorkspaceId> projectWorkspaceIds = <WorkspaceId>[
  GalleryWorkspaceIds.acme,
  GalleryWorkspaceIds.personal,
];
const List<String> _branchNames = <String>['main', 'develop', 'release/2.4'];
const int _largestRepositoryCount = 4;
const int _largestExtraProjectCount = 4;
const int _largestSuffixRepeat = 3;

typedef CountedProjects = ({
  FakeProjectRepository repository,
  NotificationCounter notifications,
  List<Project> seeded,
});

String randomCanonicalAddress(Random random) {
  final String host = randomRepositoryHost(random);
  final String owner = randomPathPartWithoutGitSuffix(random);
  final String name = randomPathPartWithoutGitSuffix(random);
  return '$host/$owner/$name';
}

String spellAddressDifferently(Random random, String canonical) {
  final List<String> parts = canonical.split('/');
  final String host = scrambleLetterCase(random, parts[0]);
  final String path = '${parts[1]}/${parts[2]}';
  final String suffix = gitSuffix * random.nextInt(_largestSuffixRepeat);
  final String slashes = '/' * random.nextInt(_largestSuffixRepeat);
  final String spelled = pickOne(random, <String>[
    '$host/$path',
    'https://$host/$path',
    'HTTPS://$host/$path',
    'git@$host:$path',
  ]);
  final String padding = ' ' * random.nextInt(_largestSuffixRepeat);
  return '$padding$spelled$suffix$slashes$padding';
}

Repository randomRepositoryAt(Random random, String address) {
  return Repository(
    address: address,
    defaultBranch: pickOne(random, _branchNames),
    agentAccess: pickOne(random, AgentAccess.values),
  );
}

List<Repository> randomDistinctRepositories(Random random) {
  final int count = random.nextInt(_largestRepositoryCount);
  final List<String> addresses = <String>[];
  while (addresses.length < count) {
    final String address = randomCanonicalAddress(random);
    if (!addresses.contains(address)) {
      addresses.add(address);
    }
  }
  return <Repository>[
    for (final String address in addresses)
      randomRepositoryAt(random, address),
  ];
}

Project randomProjectWithId(Random random, ProjectId id) {
  return Project(
    id: id,
    workspaceId: pickOne(random, projectWorkspaceIds),
    name: 'project-${random.nextInt(1000)}',
    repositories: randomDistinctRepositories(random),
    approvalPolicy: pickOne(random, inheritableApprovalPolicies),
  );
}

List<Project> randomSeededProjects(Random random) {
  final int extraCount = random.nextInt(_largestExtraProjectCount);
  return <Project>[
    ...galleryProjects,
    for (int i = 0; i < extraCount; i += 1)
      randomProjectWithId(random, ProjectId('seeded-project-$i')),
  ];
}

CountedProjects buildCountedProjects(List<Project> seeded) {
  final FakeProjectRepository repository = FakeProjectRepository(
    projects: seeded,
    taskWork: buildEmptyTaskWork(),
  );
  final NotificationCounter notifications = NotificationCounter();
  repository.addListener(notifications.record);
  return (
    repository: repository,
    notifications: notifications,
    seeded: seeded,
  );
}

List<String> listAddresses(Project project) {
  return <String>[
    for (final Repository repository in project.repositories)
      repository.address,
  ];
}

List<ProjectId> listAllProjectIds(FakeProjectRepository repository) {
  return <ProjectId>[
    for (final WorkspaceId workspaceId in projectWorkspaceIds)
      for (final Project project in repository.listProjects(workspaceId))
        project.id,
  ];
}
