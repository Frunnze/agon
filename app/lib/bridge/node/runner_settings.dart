import 'package:agent_orchestration/bridge/codecs/json_values.dart';

enum ContainerEngineChoice implements WireNamed {
  docker('docker'),
  podman('podman');

  const ContainerEngineChoice(this.wireName);

  @override
  final String wireName;

  static ContainerEngineChoice decode(Object? json) {
    return decodeWireName(values, json);
  }
}

enum AgentPlace implements WireNamed {
  container('container'),
  localProcess('local_process');

  const AgentPlace(this.wireName);

  @override
  final String wireName;

  static AgentPlace decode(Object? json) => decodeWireName(values, json);
}

sealed class SandboxSettings implements JsonEncodable {
  const SandboxSettings();

  factory SandboxSettings.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    final String kind = readField(fields, 'kind', decodeText);
    return switch (kind) {
      LocalProcessSandbox.kind => const LocalProcessSandbox(),
      ContainerSandbox.kind => ContainerSandbox(
        engine: readField(fields, 'engine', ContainerEngineChoice.decode),
        image: readField(fields, 'image', decodeText),
        allowedHosts: readListField(fields, 'allowed_hosts', decodeText),
      ),
      _ => throw FormatException('unknown sandbox $kind'),
    };
  }
}

final class LocalProcessSandbox extends SandboxSettings {
  const LocalProcessSandbox();

  static const String kind = 'local_process';

  @override
  JsonObject toJson() => <String, Object?>{'kind': kind};
}

final class ContainerSandbox extends SandboxSettings {
  ContainerSandbox({
    required this.engine,
    required this.image,
    required List<String> allowedHosts,
  }) : allowedHosts = List<String>.unmodifiable(allowedHosts);

  static const String kind = 'container';

  final ContainerEngineChoice engine;
  final String image;
  final List<String> allowedHosts;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'kind': kind,
      'engine': engine.wireName,
      'image': image,
      'allowed_hosts': allowedHosts,
    };
  }
}

sealed class RunnerChoice implements JsonEncodable {
  const RunnerChoice();
}

final class DetectedRunnerSettings extends RunnerChoice {
  const DetectedRunnerSettings();

  @override
  Object? toJson() => null;
}

final class NoRunner extends RunnerChoice {
  const NoRunner();

  static const String wireName = 'off';

  @override
  Object? toJson() => wireName;
}

final class RunnerSettings extends RunnerChoice {
  RunnerSettings({
    required List<String> labels,
    required this.slotCapacity,
    required this.sandbox,
    required this.cloneUrlTemplate,
  }) : labels = List<String>.unmodifiable(labels);

  factory RunnerSettings.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return RunnerSettings(
      labels: readListField(fields, 'labels', decodeText),
      slotCapacity: readField(fields, 'slot_capacity', decodeInteger),
      sandbox: readField(fields, 'sandbox', SandboxSettings.fromJson),
      cloneUrlTemplate: readOptionalField(
        fields,
        'clone_url_template',
        decodeText,
      ),
    );
  }

  final List<String> labels;
  final int slotCapacity;
  final SandboxSettings sandbox;
  final String? cloneUrlTemplate;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'labels': labels,
      'slot_capacity': slotCapacity,
      'sandbox': sandbox.toJson(),
      'clone_url_template': cloneUrlTemplate,
    };
  }
}
