import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/account_values.dart';
import 'package:agent_orchestration/bridge/codecs/server_group_values.dart';

import '../../support/random_inputs.dart';
import '../support/random_account_json.dart';

const List<String> _unknownStandings = <String>[
  'primary',
  'Active',
  'standby',
  '',
];

void main() {
  test('test_app_servers_view_from_json_property_keeps_every_server', () {
    final Random random = seededRandom(4901);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Map<String, Object?> json = randomAppServersJson(random);
      final List<Object?> servers = json['servers']! as List<Object?>;

      final AppServersView decoded = AppServersView.fromJson(json);

      expect(decoded.servers.length, servers.length);
      for (int index = 0; index < servers.length; index += 1) {
        final Map<String, Object?> server =
            servers[index]! as Map<String, Object?>;
        expect(decoded.servers[index].deviceId.value, server['device_id']);
        expect(decoded.servers[index].standing.wireName, server['standing']);
      }
      expect(decoded.thisDevice.wireName, json['this_device']);
      expect(decoded.canKeepBackup, json['can_keep_backup']);
    }
  });

  test('test_app_servers_view_from_json_property_servers_are_frozen', () {
    final Random random = seededRandom(4902);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppServersView decoded = AppServersView.fromJson(
        randomAppServersJson(random),
      );
      final AppServerView extra = AppServerView.fromJson(
        randomAppServerJson(random),
      );

      expect(() => decoded.servers.add(extra), throwsUnsupportedError);
    }
  });

  test('test_app_server_view_from_json_property_rejects_unknown_standing', () {
    final Random random = seededRandom(4903);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Map<String, Object?> json = <String, Object?>{
        ...randomAppServerJson(random),
        'standing': pickOne(random, _unknownStandings),
      };

      expect(
        () => AppServerView.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    }
  });

  test('test_app_servers_view_from_json_property_requires_every_field', () {
    final Random random = seededRandom(4904);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Map<String, Object?> json = randomAppServersJson(random);
      final String missing = pickOne(random, json.keys.toList());
      json.remove(missing);

      expect(
        () => AppServersView.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    }
  });

  test('test_status_view_from_json_property_requires_app_servers', () {
    final Random random = seededRandom(4905);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Map<String, Object?> json = randomStatusViewJson(random);
      final Map<String, Object?> appServers =
          json['app_servers']! as Map<String, Object?>;

      final StatusView decoded = StatusView.fromJson(json);
      expect(decoded.appServers.toJson(), equals(appServers));

      json.remove('app_servers');
      expect(() => StatusView.fromJson(json), throwsA(isA<FormatException>()));
    }
  });
}
