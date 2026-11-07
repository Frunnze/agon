import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/server_group_values.dart'
    as node;
import 'package:agent_orchestration/data/models/app_server_group.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../bridge/support/list_copy_properties.dart';
import '../../bridge/support/random_moments.dart';
import '../../bridge/support/random_typed_values.dart';
import '../../support/random_inputs.dart';
import 'support/domain_model_properties.dart';

const int _largestSafeInteger = 9007199254740991;
const int _commonChangeCountSpan = 1000;
const DeviceId _anyDeviceId = DeviceId('device');

int _randomChangeCount(Random random) {
  return pickOne(random, <int>[
    0,
    1,
    _largestSafeInteger,
    random.nextInt(_commonChangeCountSpan),
  ]);
}

BackupCopy _randomBackupCopy(Random random) {
  return BackupCopy(
    changesBehind: _randomChangeCount(random),
    verifiedAt: randomPreciseMoment(random),
  );
}

AppServerMember _randomMember(Random random) {
  return AppServerMember(
    deviceId: randomDeviceId(random),
    standing: pickOne(random, ServerStanding.values),
    copy: random.nextBool() ? null : _randomBackupCopy(random),
  );
}

List<AppServerMember> _randomMembers(Random random) {
  final List<AppServerMember> members = <AppServerMember>[];
  final int count = random.nextInt(5);
  for (int i = 0; i < count; i += 1) {
    members.add(_randomMember(random));
  }
  return members;
}

AppServerGroup _groupWith({
  required node.ServerStanding standing,
  required node.ThisDeviceStanding thisDevice,
}) {
  final node.AppServersView view = node.AppServersView(
    servers: <node.AppServerView>[
      node.AppServerView(
        deviceId: _anyDeviceId,
        standing: standing,
        copy: null,
      ),
    ],
    thisDevice: thisDevice,
    canKeepBackup: true,
  );
  return mapAppServerGroupFromNode(view);
}

ServerStanding _mapServerStandingThroughGroup(node.ServerStanding standing) {
  final AppServerGroup group = _groupWith(
    standing: standing,
    thisDevice: node.ThisDeviceStanding.none,
  );
  return group.members.single.standing;
}

ThisDeviceStanding _mapThisDeviceStandingThroughGroup(
  node.ThisDeviceStanding standing,
) {
  final AppServerGroup group = _groupWith(
    standing: node.ServerStanding.active,
    thisDevice: standing,
  );
  return group.thisDeviceStanding;
}

void main() {
  testModelConstructorProperties(
    ModelConstructor<BackupCopy>(
      testNamePrefix: 'test_backup_copy_constructor_property',
      seed: 690201,
      randomFieldValues: (Random random) => <Object?>[
        _randomChangeCount(random),
        randomPreciseMoment(random),
      ],
      construct: (ModelFieldValues fieldValues) => BackupCopy(
        changesBehind: fieldValues[0]! as int,
        verifiedAt: fieldValues[1]! as DateTime,
      ),
      readFieldValues: (BackupCopy copy) => <Object?>[
        copy.changesBehind,
        copy.verifiedAt,
      ],
    ),
  );

  testModelConstructorProperties(
    ModelConstructor<AppServerMember>(
      testNamePrefix: 'test_app_server_member_constructor_property',
      seed: 690211,
      randomFieldValues: (Random random) => <Object?>[
        randomDeviceId(random),
        pickOne(random, ServerStanding.values),
        if (random.nextBool()) null else _randomBackupCopy(random),
      ],
      construct: (ModelFieldValues fieldValues) => AppServerMember(
        deviceId: fieldValues[0]! as DeviceId,
        standing: fieldValues[1]! as ServerStanding,
        copy: fieldValues[2] as BackupCopy?,
      ),
      readFieldValues: (AppServerMember member) => <Object?>[
        member.deviceId,
        member.standing,
        member.copy,
      ],
    ),
  );

  testModelConstructorProperties(
    ModelConstructor<AppServerGroup>(
      testNamePrefix: 'test_app_server_group_constructor_property',
      seed: 690221,
      randomFieldValues: (Random random) => <Object?>[
        _randomMembers(random),
        pickOne(random, ThisDeviceStanding.values),
        random.nextBool(),
      ],
      construct: (ModelFieldValues fieldValues) => AppServerGroup(
        members: fieldValues[0]! as List<AppServerMember>,
        thisDeviceStanding: fieldValues[1]! as ThisDeviceStanding,
        canKeepBackup: fieldValues[2]! as bool,
      ),
      readFieldValues: (AppServerGroup group) => <Object?>[
        group.members,
        group.thisDeviceStanding,
        group.canKeepBackup,
      ],
    ),
  );

  testListCopyProperties(
    ListCopy<AppServerGroup, AppServerMember>(
      testNamePrefix: 'test_app_server_group_constructor_property_members',
      seed: 690231,
      buildElement: _randomMember,
      construct: (Random random, List<AppServerMember> members) =>
          AppServerGroup(
            members: members,
            thisDeviceStanding: pickOne(random, ThisDeviceStanding.values),
            canKeepBackup: random.nextBool(),
          ),
      readList: (AppServerGroup group) => group.members,
    ),
  );

  testNodeEnumMappingProperties(
    const NodeEnumMapping<ServerStanding, node.ServerStanding>(
      testNamePrefix: 'test_server_standing_values_property',
      choices: ServerStanding.values,
      nodeChoices: node.ServerStanding.values,
      mapFromNode: _mapServerStandingThroughGroup,
    ),
  );

  testNodeEnumMappingProperties(
    const NodeEnumMapping<ThisDeviceStanding, node.ThisDeviceStanding>(
      testNamePrefix: 'test_this_device_standing_values_property',
      choices: ThisDeviceStanding.values,
      nodeChoices: node.ThisDeviceStanding.values,
      mapFromNode: _mapThisDeviceStandingThroughGroup,
    ),
  );
}
