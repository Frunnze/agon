import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/server_group_values.dart';

import '../../support/random_inputs.dart';
import '../support/list_copy_properties.dart';
import '../support/node_wire_names.dart';
import '../support/random_account_json.dart';
import '../support/random_typed_values.dart';
import '../support/utc_offset_moments.dart';
import '../support/wire_codec_properties.dart';
import '../support/wire_json_edits.dart';
import '../support/wire_name_decoder_properties.dart';

const int _firstFamilySeed = 53000;
const int _seedsPerFamily = 2;
const int _largestChangesBehind = 100000;

const List<WireNameDecoderFamily> _standingFamilies = <WireNameDecoderFamily>[
  WireNameDecoderFamily(
    typeName: 'server_standing',
    choices: ServerStanding.values,
    nodeNames: nodeServerStandings,
    decode: ServerStanding.decode,
  ),
  WireNameDecoderFamily(
    typeName: 'this_device_standing',
    choices: ThisDeviceStanding.values,
    nodeNames: nodeThisDeviceStandings,
    decode: ThisDeviceStanding.decode,
  ),
];

const List<WireCodec> _serverGroupCodecs = <WireCodec>[
  WireCodec(
    typeName: 'backup_copy_view',
    seed: 53010,
    buildJson: randomBackupCopyJson,
    decode: BackupCopyView.fromJson,
    requiredFields: <String>{'changes_behind', 'verified_at'},
    optionalFields: <String>{},
  ),
  WireCodec(
    typeName: 'app_server_view',
    seed: 53020,
    buildJson: randomAppServerJson,
    decode: AppServerView.fromJson,
    requiredFields: <String>{'device_id', 'standing'},
    optionalFields: <String>{'copy'},
  ),
  WireCodec(
    typeName: 'app_servers_view',
    seed: 53030,
    buildJson: randomAppServersJson,
    decode: AppServersView.fromJson,
    requiredFields: <String>{'servers', 'this_device', 'can_keep_backup'},
    optionalFields: <String>{},
  ),
];

AppServerView _buildAppServer(Random random) {
  return AppServerView.fromJson(randomAppServerJson(random));
}

AppServersView _buildAppServers(Random random, List<AppServerView> servers) {
  return AppServersView(
    servers: servers,
    thisDevice: pickOne(random, ThisDeviceStanding.values),
    canKeepBackup: random.nextBool(),
  );
}

List<AppServerView> _readServers(AppServersView view) => view.servers;

void main() {
  for (int index = 0; index < _standingFamilies.length; index += 1) {
    final WireNameDecoderFamily family = _standingFamilies[index];
    final int seed = _firstFamilySeed + index * _seedsPerFamily;

    testDecodeReadsEveryNodeName(family);
    testDecodeRejectsNearMissNames(family, seed);
    testDecodeRejectsAnythingButANodeName(family, seed + 1);
  }

  for (final WireCodec codec in _serverGroupCodecs) {
    testWireDecodingProperties(codec);
    testWireEncodingProperties(codec);
  }

  testListCopyProperties(
    const ListCopy<AppServersView, AppServerView>(
      testNamePrefix: 'test_app_servers_view_constructor_property_servers',
      seed: 53040,
      buildElement: _buildAppServer,
      construct: _buildAppServers,
      readList: _readServers,
    ),
  );

  test('test_server_standing_decode_property_'
      'rejects_every_this_device_only_name', () {
    final List<String> thisDeviceOnlyNames = <String>[];
    for (final String nodeName in nodeThisDeviceStandings) {
      if (!nodeServerStandings.contains(nodeName)) {
        thisDeviceOnlyNames.add(nodeName);
      }
    }

    expect(thisDeviceOnlyNames, isNotEmpty);
    for (final String nodeName in thisDeviceOnlyNames) {
      expect(() => ServerStanding.decode(nodeName), throwsFormatException);
    }
  });

  test('test_this_device_standing_decode_property_'
      'shares_every_server_standing_name', () {
    for (final ServerStanding standing in ServerStanding.values) {
      final ThisDeviceStanding thisDevice = ThisDeviceStanding.decode(
        standing.wireName,
      );

      expect(thisDevice.wireName, standing.wireName);
    }
  });

  test('test_backup_copy_view_to_json_property_'
      'writes_verified_at_as_utc_text', () {
    final Random random = seededRandom(53050);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime verifiedAt = randomMicrosecondMoment(random);
      final BackupCopyView copy = BackupCopyView(
        changesBehind: random.nextInt(_largestChangesBehind),
        verifiedAt: verifiedAt,
      );

      expectUtcMomentText(copy.toJson()['verified_at'], verifiedAt);
    }
  });

  test('test_backup_copy_view_from_json_property_'
      'reads_offset_moments_as_the_same_utc_instant', () {
    final Random random = seededRandom(53051);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime verifiedAt = randomMicrosecondMoment(random).toUtc();
      final JsonObject wireJson = replaceWireField(
        randomBackupCopyJson(random),
        'verified_at',
        writeMomentAtRandomOffset(random, verifiedAt),
      );

      final BackupCopyView copy = BackupCopyView.fromJson(wireJson);

      expect(copy.verifiedAt.isUtc, isTrue);
      expect(copy.verifiedAt, equals(verifiedAt));
    }
  });

  test('test_app_server_view_to_json_property_'
      'keeps_the_device_and_standing_given', () {
    final Random random = seededRandom(53052);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppServerView server = AppServerView(
        deviceId: randomDeviceId(random),
        standing: pickOne(random, ServerStanding.values),
        copy: null,
      );

      final AppServerView decodedAgain = AppServerView.fromJson(
        reencodeAsJsonText(server),
      );

      expect(decodedAgain.deviceId, server.deviceId);
      expect(decodedAgain.standing, server.standing);
      expect(decodedAgain.copy, isNull);
    }
  });
}
