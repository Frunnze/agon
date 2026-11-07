import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/background/channel_presence.dart';
import 'package:agent_orchestration/background/xdg_autostart.dart';
import 'package:agent_orchestration/background/xdg_autostart_login_item.dart';

import '../support/random_inputs.dart';
import 'support/autostart_expectations.dart';
import 'support/autostart_folders.dart';
import 'support/hostile_paths.dart';
import 'support/switch_contract.dart';

typedef _ChannelPresenceBuilder = _BuiltChannelPresence Function(
  MethodChannel channel,
);

const int _firstSeed = 9490070;
const int _seedsPerRow = 3;
const String _channelPrefix = 'test/presence_constructor/';
const MethodChannel _givenChannel = MethodChannel('${_channelPrefix}given');
const MethodChannel _otherChannel = MethodChannel('${_channelPrefix}other');
const List<_ChannelPresenceRow> _channelPresenceRows = <_ChannelPresenceRow>[
  _ChannelPresenceRow(
    typeName: 'channel_login_item',
    build: _buildChannelLoginItem,
  ),
  _ChannelPresenceRow(
    typeName: 'channel_tray_presence',
    build: _buildChannelTrayPresence,
  ),
];

final class _ChannelPresenceRow {
  const _ChannelPresenceRow({required this.typeName, required this.build});

  final String typeName;
  final _ChannelPresenceBuilder build;
}

final class _BuiltChannelPresence {
  const _BuiltChannelPresence({
    required this.keptChannel,
    required this.calls,
  });

  final MethodChannel keptChannel;
  final List<PresenceCall> calls;
}

final class _RecordingNativeSide {
  final List<String> methods = <String>[];

  Future<Object?> answer(MethodCall call) async {
    methods.add(call.method);
    return null;
  }
}

_BuiltChannelPresence _buildChannelLoginItem(MethodChannel channel) {
  final ChannelLoginItem loginItem = ChannelLoginItem(channel: channel);
  return _BuiltChannelPresence(
    keptChannel: loginItem.channel,
    calls: <PresenceCall>[loginItem.register, loginItem.unregister],
  );
}

_BuiltChannelPresence _buildChannelTrayPresence(MethodChannel channel) {
  final ChannelTrayPresence trayPresence = ChannelTrayPresence(
    channel: channel,
  );
  return _BuiltChannelPresence(
    keptChannel: trayPresence.channel,
    calls: <PresenceCall>[trayPresence.stayInTray, trayPresence.leaveTray],
  );
}

MethodChannel _randomChannel(Random random) {
  return MethodChannel('$_channelPrefix${randomText(random)}');
}

_RecordingNativeSide _listenOn(MethodChannel channel) {
  final _RecordingNativeSide nativeSide = _RecordingNativeSide();
  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(channel, nativeSide.answer);
  addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  return nativeSide;
}

void _testChannelPresenceConstructor({
  required _ChannelPresenceRow row,
  required int seed,
}) {
  final String testPrefix = 'test_${row.typeName}_constructor_property';

  test('${testPrefix}_keeps_the_channel', () {
    final Random random = seededRandom(seed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final MethodChannel channel = _randomChannel(random);

      expect(identical(row.build(channel).keptChannel, channel), isTrue);
    }
  });

  test('${testPrefix}_calls_reach_only_the_given_channel', () async {
    final Random random = seededRandom(seed + 1);

    for (int i = 0; i < contractIterations; i += 1) {
      final _RecordingNativeSide givenSide = _listenOn(_givenChannel);
      final _RecordingNativeSide otherSide = _listenOn(_otherChannel);
      final PresenceCall call = pickOne(
        random,
        row.build(_givenChannel).calls,
      );

      await call();

      expect(givenSide.methods, hasLength(1));
      expect(otherSide.methods, isEmpty);
    }
  });

  test('${testPrefix}_constructing_sends_nothing', () {
    final Random random = seededRandom(seed + 2);

    for (int i = 0; i < contractIterations; i += 1) {
      final MethodChannel channel = _randomChannel(random);
      final _RecordingNativeSide nativeSide = _listenOn(channel);

      expect(row.build(channel).calls, isNotEmpty);
      expect(nativeSide.methods, isEmpty);
    }
  });
}

XdgAutostartLoginItem _randomXdgLoginItem(Random random) {
  return XdgAutostartLoginItem(
    environment: randomEnvironmentInside(random, createTemporaryFolder()),
    executablePath: randomHostileAbsolutePath(random),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (int i = 0; i < _channelPresenceRows.length; i += 1) {
    _testChannelPresenceConstructor(
      row: _channelPresenceRows[i],
      seed: _firstSeed + i * _seedsPerRow,
    );
  }

  test(
    'test_xdg_autostart_login_item_constructor_property_keeps_every_field',
    () {
      final Random random = seededRandom(_firstSeed + 10);

      for (int i = 0; i < contractIterations; i += 1) {
        final Map<String, String> environment = randomEnvironmentInside(
          random,
          createTemporaryFolder(),
        );
        final String executablePath = randomHostileAbsolutePath(random);
        final XdgAutostartLoginItem loginItem = XdgAutostartLoginItem(
          environment: environment,
          executablePath: executablePath,
        );

        expect(identical(loginItem.environment, environment), isTrue);
        expect(loginItem.executablePath, executablePath);
      }
    },
  );

  test(
    'test_xdg_autostart_login_item_constructor_property_touches_no_files',
    () {
      final Random random = seededRandom(_firstSeed + 11);

      for (int i = 0; i < contractIterations; i += 1) {
        final Directory root = createTemporaryFolder();
        final XdgAutostartLoginItem loginItem = XdgAutostartLoginItem(
          environment: randomEnvironmentInside(random, root),
          executablePath: randomHostileAbsolutePath(random),
        );

        expect(loginItem.executablePath, isNotEmpty);
        expect(root.listSync(), isEmpty);
      }
    },
  );

  test(
    'test_xdg_autostart_login_item_constructor_property_register_uses_them',
    () async {
      final Random random = seededRandom(_firstSeed + 12);

      for (int i = 0; i < contractIterations; i += 1) {
        final XdgAutostartLoginItem loginItem = _randomXdgLoginItem(random);
        final File entry = File(locateAutostartEntry(loginItem.environment));

        await loginItem.register();

        expect(
          entry.readAsStringSync(),
          renderAutostartEntry(loginItem.executablePath),
        );
      }
    },
  );
}
