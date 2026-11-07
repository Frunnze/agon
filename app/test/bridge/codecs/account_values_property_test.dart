import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/account_values.dart';
import 'package:agent_orchestration/bridge/codecs/device_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart';

import '../../support/random_inputs.dart';
import '../support/list_copy_properties.dart';
import '../support/node_json_primitives.dart';
import '../support/random_account_json.dart';
import '../support/random_catalog_json.dart';
import '../support/utc_offset_moments.dart';
import '../support/wire_codec_properties.dart';

const int _byteValueCount = 256;

const List<WireCodec> _accountCodecs = <WireCodec>[
  WireCodec(
    typeName: 'account_summary',
    seed: 49100,
    buildJson: randomAccountSummaryJson,
    decode: AccountSummary.fromJson,
    requiredFields: <String>{'device', 'workspaces'},
    optionalFields: <String>{},
  ),
  WireCodec(
    typeName: 'server_health_view',
    seed: 49110,
    buildJson: randomServerHealthJson,
    decode: ServerHealthView.fromJson,
    requiredFields: <String>{'reachable', 'checked_at'},
    optionalFields: <String>{'problem'},
  ),
  WireCodec(
    typeName: 'pending_join',
    seed: 49120,
    buildJson: randomPendingJoinJson,
    decode: PendingJoin.fromJson,
    requiredFields: <String>{'join_id', 'display_code'},
    optionalFields: <String>{},
  ),
  WireCodec(
    typeName: 'peer_address',
    seed: 49130,
    buildJson: randomPeerAddressJson,
    decode: PeerAddress.fromJson,
    requiredFields: <String>{'endpoint_public_key', 'direct_addresses'},
    optionalFields: <String>{'relay_url'},
  ),
  WireCodec(
    typeName: 'peer_announcement',
    seed: 49140,
    buildJson: randomPeerAnnouncementJson,
    decode: PeerAnnouncement.fromJson,
    requiredFields: <String>{},
    optionalFields: <String>{'published_address', 'problem'},
  ),
  WireCodec(
    typeName: 'status_view',
    seed: 49150,
    buildJson: randomStatusViewJson,
    decode: StatusView.fromJson,
    requiredFields: <String>{'server_reachable', 'app_servers'},
    optionalFields: <String>{
      'server_address',
      'hosted_server_address',
      'device_id',
      'account',
      'pending_join',
      'peer',
      'rendezvous_problem',
      'runner_settings',
    },
  ),
];

void main() {
  for (final WireCodec codec in _accountCodecs) {
    testWireDecodingProperties(codec);
    testWireEncodingProperties(codec);
  }

  testListCopyProperties(
    const ListCopy<AccountSummary, Workspace>(
      testNamePrefix: 'test_account_summary_constructor_property_workspaces',
      seed: 49160,
      buildElement: _buildWorkspace,
      construct: _buildAccountSummary,
      readList: _readWorkspaces,
    ),
  );

  testListCopyProperties(
    const ListCopy<PeerAddress, int>(
      testNamePrefix:
          'test_peer_address_constructor_property_endpoint_public_key',
      seed: 49170,
      buildElement: _buildByte,
      construct: _buildPeerAddressWithKey,
      readList: _readEndpointPublicKey,
    ),
  );

  testListCopyProperties(
    const ListCopy<PeerAddress, String>(
      testNamePrefix:
          'test_peer_address_constructor_property_direct_addresses',
      seed: 49180,
      buildElement: randomText,
      construct: _buildPeerAddressWithAddresses,
      readList: _readDirectAddresses,
    ),
  );

  test('test_server_health_view_from_json_property_'
      'any_offset_keeps_the_instant', () {
    final Random random = seededRandom(49190);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime checkedAt = randomMicrosecondMoment(random).toUtc();
      final Map<String, Object?> wireJson = randomServerHealthJson(random);
      wireJson['checked_at'] = writeMomentAtRandomOffset(random, checkedAt);

      final ServerHealthView view = ServerHealthView.fromJson(wireJson);

      expect(view.checkedAt, checkedAt);
      expect(view.checkedAt.isUtc, isTrue);
    }
  });

  test('test_server_health_view_to_json_property_'
      'writes_checked_at_as_utc_text', () {
    final Random random = seededRandom(49195);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime checkedAt = randomMicrosecondMoment(random);
      final ServerHealthView view = ServerHealthView(
        reachable: random.nextBool(),
        checkedAt: checkedAt,
        problem: null,
      );

      expectUtcMomentText(view.toJson()['checked_at'], checkedAt);
    }
  });
}

Workspace _buildWorkspace(Random random) {
  return Workspace.fromJson(randomWorkspaceJson(random));
}

AccountSummary _buildAccountSummary(
  Random random,
  List<Workspace> workspaces,
) {
  final Device device = Device.fromJson(randomDeviceJson(random));
  return AccountSummary(device: device, workspaces: workspaces);
}

List<Workspace> _readWorkspaces(AccountSummary summary) => summary.workspaces;

int _buildByte(Random random) => random.nextInt(_byteValueCount);

PeerAddress _buildPeerAddressWithKey(Random random, List<int> key) {
  return PeerAddress(
    endpointPublicKey: key,
    directAddresses: decodeList(randomTexts(random), decodeText),
    relayUrl: null,
  );
}

PeerAddress _buildPeerAddressWithAddresses(
  Random random,
  List<String> directAddresses,
) {
  return PeerAddress(
    endpointPublicKey: randomBytes(random),
    directAddresses: directAddresses,
    relayUrl: randomText(random),
  );
}

List<int> _readEndpointPublicKey(PeerAddress address) {
  return address.endpointPublicKey;
}

List<String> _readDirectAddresses(PeerAddress address) {
  return address.directAddresses;
}
