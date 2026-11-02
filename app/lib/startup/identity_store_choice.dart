import 'dart:math';

import 'package:agent_orchestration/bridge/native/native_library_source.dart';
import 'package:agent_orchestration/bridge/node/node_start_configuration.dart';
import 'package:agent_orchestration/data/secret_store.dart';
import 'package:agent_orchestration/startup/app_build_mode.dart';

const String identityKeySecretName = 'node_identity_key';
const int _identityKeyByteCount = 32;
const int _byteValueCount = 256;
const int _hexadecimalBase = 16;
const int _hexadecimalDigitsPerByte = 2;
const Set<String> _phoneSystems = <String>{androidSystemName, iosSystemName};

String _generateIdentityKey(Random random) {
  final StringBuffer key = StringBuffer();
  for (int i = 0; i < _identityKeyByteCount; i += 1) {
    final int byte = random.nextInt(_byteValueCount);
    key.write(
      byte
          .toRadixString(_hexadecimalBase)
          .padLeft(_hexadecimalDigitsPerByte, '0'),
    );
  }
  return key.toString();
}

Future<String> readOrCreateIdentityKey({
  required SecretStore secrets,
  required Random random,
}) async {
  final String? storedKey = await secrets.readSecret(identityKeySecretName);
  if (storedKey != null) {
    if (!isIdentityKey(storedKey)) {
      throw const FormatException('the stored identity key is damaged');
    }
    return storedKey;
  }

  final String createdKey = _generateIdentityKey(random);
  await secrets.writeSecret(name: identityKeySecretName, value: createdKey);
  return createdKey;
}

Future<IdentityStoreSettings> chooseIdentityStore({
  required String operatingSystem,
  required AppBuildMode buildMode,
  required SecretStore secrets,
  required Random random,
}) async {
  final bool isPhone = _phoneSystems.contains(operatingSystem);
  if (!isPhone && buildMode == AppBuildMode.debug) {
    return const FileIdentityStore();
  }
  if (!isPhone) {
    return const KeychainIdentityStore();
  }
  final String key = await readOrCreateIdentityKey(
    secrets: secrets,
    random: random,
  );
  return EncryptedFileIdentityStore(key: key);
}
