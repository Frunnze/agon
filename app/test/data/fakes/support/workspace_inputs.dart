import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/app_server_group.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workspace.dart';

import '../../../support/random_inputs.dart';

const DeviceId thisWorkspaceDeviceId = GalleryDeviceIds.airLaptop;
const int _largestWorkspaceCount = 4;
const List<DeviceId> _otherServerIds = <DeviceId>[
  GalleryDeviceIds.mainMac,
  GalleryDeviceIds.oldMacbook,
  GalleryDeviceIds.officeServer,
];
const List<String> _patternSamples = <String>[
  '.env',
  'secrets/*.pem',
  '~/.ssh',
  'config/credentials.json',
  'café/clé.txt',
];

final String _longestValidName = 'n' * 40;
final String _tooLongName = 'n' * 41;

typedef SeededWorkspaces = ({
  FakeWorkspaceRepository repository,
  List<Workspace> workspaces,
});

FakeWorkspaceRepository buildWorkspaceRepository({
  required List<Workspace> workspaces,
  required WorkspaceId currentWorkspaceId,
  required AppServerGroup appServerGroup,
}) {
  return FakeWorkspaceRepository(
    workspaces: workspaces,
    currentWorkspaceId: currentWorkspaceId,
    appServerStatus: galleryAppServerStatus,
    appServerGroup: appServerGroup,
    currentDeviceId: thisWorkspaceDeviceId,
    clock: FixedClock(galleryNow),
  );
}

Workspace buildSampleWorkspace(Random random, int index) {
  return Workspace(
    id: WorkspaceId('seeded-workspace-$index'),
    name: 'team-$index',
    appServerAddress: galleryAppServerStatus.address,
    protectedFiles: randomPatterns(random),
    approvalPolicy: pickOne(random, ApprovalPolicy.values),
  );
}

List<Workspace> randomWorkspaces(Random random) {
  final int count = 1 + random.nextInt(_largestWorkspaceCount);
  return <Workspace>[
    for (int index = 0; index < count; index += 1)
      buildSampleWorkspace(random, index),
  ];
}

SeededWorkspaces seedRandomWorkspaces(Random random) {
  final List<Workspace> workspaces = randomWorkspaces(random);
  final FakeWorkspaceRepository repository = buildWorkspaceRepository(
    workspaces: workspaces,
    currentWorkspaceId: pickOne(random, workspaces).id,
    appServerGroup: randomAppServerGroup(random),
  );
  return (repository: repository, workspaces: workspaces);
}

List<String> randomPatterns(Random random) {
  return <String>[
    for (final String pattern in _patternSamples)
      if (random.nextBool()) pattern,
  ];
}

String randomWorkspaceName(Random random) {
  return pickOne(random, <String>[
    'team-${random.nextInt(100)}',
    '  side-${random.nextInt(100)}  ',
    _longestValidName,
    _tooLongName,
    'Has Space',
    'UPPER',
    'under_score',
    'café',
    '',
    randomWordPhrase(random),
    randomText(random),
  ]);
}

List<AppServerMember> _randomOtherMembers(Random random) {
  final List<AppServerMember> members = <AppServerMember>[];
  for (final DeviceId deviceId in _otherServerIds) {
    if (random.nextBool()) {
      final ServerStanding standing = pickOne(random, ServerStanding.values);
      members.add(
        AppServerMember(deviceId: deviceId, standing: standing, copy: null),
      );
    }
  }
  return members;
}

AppServerGroup randomAppServerGroup(Random random) {
  final ThisDeviceStanding standing = pickOne(
    random,
    ThisDeviceStanding.values,
  );
  final List<AppServerMember> members = _randomOtherMembers(random);

  if (standing == ThisDeviceStanding.active) {
    members.add(
      const AppServerMember(
        deviceId: thisWorkspaceDeviceId,
        standing: ServerStanding.active,
        copy: null,
      ),
    );
  }
  if (standing == ThisDeviceStanding.backup) {
    members.add(
      const AppServerMember(
        deviceId: thisWorkspaceDeviceId,
        standing: ServerStanding.backup,
        copy: null,
      ),
    );
  }
  return AppServerGroup(
    members: members,
    thisDeviceStanding: standing,
    canKeepBackup: random.nextInt(4) != 0,
  );
}

bool hasActiveServer(AppServerGroup group) {
  return group.members.any(
    (AppServerMember member) => member.standing == ServerStanding.active,
  );
}

List<String> describeServerMembers(AppServerGroup group) {
  return <String>[
    for (final AppServerMember member in group.members)
      '${member.deviceId.value} ${member.standing.name}',
  ];
}

void expectOtherWorkspacesUntouched(
  FakeWorkspaceRepository repository,
  List<Workspace> before,
  Workspace changed,
) {
  final List<Workspace> after = repository.listWorkspaces();
  expect(after, hasLength(before.length));
  for (int index = 0; index < before.length; index += 1) {
    final Workspace expected = before[index].id == changed.id
        ? changed
        : before[index];
    expect(after[index], same(expected));
  }
}

const String notClientBackupProblem =
    'only a client device can keep a backup of the app server';
const String alreadyKeepingServerProblem =
    'this device already keeps the app server';
const String noActiveServerProblem = 'the app server keeps no backups';
const String activeServerProblem = 'this device is the active app server';
const String notKeepingServerProblem = 'this device keeps no app server';

FakeWorkspaceRepository buildGroupWorkspaceRepository(AppServerGroup group) {
  return buildWorkspaceRepository(
    workspaces: galleryWorkspaces,
    currentWorkspaceId: galleryWorkspaces.first.id,
    appServerGroup: group,
  );
}

String? predictStartBackupProblem(AppServerGroup group) {
  if (!group.canKeepBackup) {
    return notClientBackupProblem;
  }
  if (group.thisDeviceStanding != ThisDeviceStanding.none) {
    return alreadyKeepingServerProblem;
  }
  if (!hasActiveServer(group)) {
    return noActiveServerProblem;
  }
  return null;
}

String? predictStopBackupProblem(AppServerGroup group) {
  if (group.thisDeviceStanding == ThisDeviceStanding.active) {
    return activeServerProblem;
  }
  if (group.thisDeviceStanding == ThisDeviceStanding.none) {
    return notKeepingServerProblem;
  }
  return null;
}

Matcher throwsRefusalWith(String problem) {
  return throwsA(
    isA<StateError>().having(
      (StateError error) => error.message,
      'message',
      problem,
    ),
  );
}
