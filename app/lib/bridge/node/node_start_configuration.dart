import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/node/runner_settings.dart';

const int identityKeyHexadecimalLength = 64;
const int largestAppServerPort = 65535;
final RegExp _identityKeyPattern = RegExp(
  '^[0-9a-f]{$identityKeyHexadecimalLength}\$',
);

bool isIdentityKey(String key) => _identityKeyPattern.hasMatch(key);

sealed class IdentityStoreSettings implements JsonEncodable {
  const IdentityStoreSettings();
}

final class KeychainIdentityStore extends IdentityStoreSettings {
  const KeychainIdentityStore();

  static const String wireName = 'keychain';

  @override
  Object? toJson() => wireName;
}

final class FileIdentityStore extends IdentityStoreSettings {
  const FileIdentityStore();

  static const String wireName = 'file';

  @override
  Object? toJson() => wireName;
}

final class EncryptedFileIdentityStore extends IdentityStoreSettings {
  EncryptedFileIdentityStore({required this.key}) {
    if (!isIdentityKey(key)) {
      throw ArgumentError.value(
        key.length,
        'key',
        'the identity key must be $identityKeyHexadecimalLength '
            'lowercase hexadecimal digits',
      );
    }
  }

  static const String wireName = 'encrypted_file';

  final String key;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      wireName: <String, Object?>{'key': key},
    };
  }
}

enum PeerRelayChoice implements WireNamed {
  defaultRelay('default'),
  disabled('disabled');

  const PeerRelayChoice(this.wireName);

  @override
  final String wireName;
}

final class NodeStartConfiguration implements JsonEncodable {
  NodeStartConfiguration({
    required this.dataDirectory,
    required this.identityStore,
    required this.runner,
    required this.peerRelay,
    this.appServerPort,
  }) {
    if (dataDirectory.trim().isEmpty) {
      throw ArgumentError.value(
        dataDirectory,
        'dataDirectory',
        'the node needs a data directory',
      );
    }

    final int? port = appServerPort;
    if (port != null && (port < 0 || port > largestAppServerPort)) {
      throw ArgumentError.value(
        port,
        'appServerPort',
        'a port is a whole number from 0 to $largestAppServerPort',
      );
    }
  }

  final String dataDirectory;
  final IdentityStoreSettings identityStore;
  final RunnerChoice runner;
  final PeerRelayChoice peerRelay;
  final int? appServerPort;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'data_directory': dataDirectory,
      'identity_store': identityStore.toJson(),
      'runner': runner.toJson(),
      'peer_relay': peerRelay.wireName,
      'app_server_port': ?appServerPort,
    };
  }
}
