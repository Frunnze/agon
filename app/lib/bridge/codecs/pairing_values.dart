import 'package:agent_orchestration/bridge/codecs/account_values.dart';
import 'package:agent_orchestration/bridge/codecs/device_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';

final class JoiningDevice implements JsonEncodable {
  JoiningDevice({
    required this.name,
    required this.role,
    required this.keyKind,
    required List<int> sealingPublicKey,
    required List<String> fingerprintWords,
  }) : sealingPublicKey = List<int>.unmodifiable(sealingPublicKey),
       fingerprintWords = List<String>.unmodifiable(fingerprintWords);

  factory JoiningDevice.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return JoiningDevice(
      name: readField(fields, 'name', decodeText),
      role: readField(fields, 'role', DeviceRole.decode),
      keyKind: readField(fields, 'key_kind', HardwareKeyKind.decode),
      sealingPublicKey: readListField(
        fields,
        'sealing_public_key',
        decodeInteger,
      ),
      fingerprintWords: readListField(fields, 'fingerprint_words', decodeText),
    );
  }

  final String name;
  final DeviceRole role;
  final HardwareKeyKind keyKind;
  final List<int> sealingPublicKey;
  final List<String> fingerprintWords;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'name': name,
      'role': role.wireName,
      'key_kind': keyKind.wireName,
      'sealing_public_key': sealingPublicKey,
      'fingerprint_words': fingerprintWords,
    };
  }
}

const String _fingerprintWordsField = 'fingerprint_words';

final class PairingRequestScreen implements JsonEncodable {
  const PairingRequestScreen({
    required this.code,
    required this.displayCode,
    required this.startedAt,
    required this.expiresAt,
    required this.joining,
  });

  factory PairingRequestScreen.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return PairingRequestScreen(
      code: readField(fields, 'code', decodeText),
      displayCode: readField(fields, 'display_code', decodeText),
      startedAt: readField(fields, 'started_at', decodeMoment),
      expiresAt: readField(fields, 'expires_at', decodeMoment),
      joining: readOptionalField(fields, 'joining', JoiningDevice.fromJson),
    );
  }

  final String code;
  final String displayCode;
  final DateTime startedAt;
  final DateTime expiresAt;
  final JoiningDevice? joining;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'code': code,
      'display_code': displayCode,
      'started_at': encodeMoment(startedAt),
      'expires_at': encodeMoment(expiresAt),
      'joining': joining?.toJson(),
    };
  }
}

sealed class JoinStatusView implements JsonEncodable {
  JoinStatusView({required List<String> fingerprintWords})
    : fingerprintWords = List<String>.unmodifiable(fingerprintWords);

  factory JoinStatusView.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    final String state = readField(fields, 'state', decodeText);
    final List<String> words = readListField(
      fields,
      _fingerprintWordsField,
      decodeText,
    );
    return switch (state) {
      JoinWaiting.state => JoinWaiting(fingerprintWords: words),
      JoinApproved.state => JoinApproved(
        fingerprintWords: words,
        account: AccountSummary.fromJson(fields),
      ),
      JoinRejected.state => JoinRejected(fingerprintWords: words),
      JoinExpired.state => JoinExpired(fingerprintWords: words),
      _ => throw FormatException('unknown join state $state'),
    };
  }

  final List<String> fingerprintWords;

  String get joinState;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'state': joinState,
      _fingerprintWordsField: fingerprintWords,
    };
  }
}

final class JoinWaiting extends JoinStatusView {
  JoinWaiting({required super.fingerprintWords});

  static const String state = 'waiting';

  @override
  String get joinState => state;
}

final class JoinApproved extends JoinStatusView {
  JoinApproved({required super.fingerprintWords, required this.account});

  static const String state = 'approved';

  final AccountSummary account;

  @override
  String get joinState => state;

  @override
  JsonObject toJson() {
    return <String, Object?>{...super.toJson(), ...account.toJson()};
  }
}

final class JoinRejected extends JoinStatusView {
  JoinRejected({required super.fingerprintWords});

  static const String state = 'rejected';

  @override
  String get joinState => state;
}

final class JoinExpired extends JoinStatusView {
  JoinExpired({required super.fingerprintWords});

  static const String state = 'expired';

  @override
  String get joinState => state;
}
