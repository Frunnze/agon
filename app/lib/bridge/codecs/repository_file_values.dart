import 'package:agent_orchestration/bridge/codecs/identifier_codecs.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

const String _kindField = 'kind';
const String _deviceIdField = 'device_id';
const String _nameField = 'name';
const String _sizeField = 'size';

sealed class RepositoryBranchesView implements JsonEncodable {
  const RepositoryBranchesView();

  factory RepositoryBranchesView.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    final String kind = readField(fields, _kindField, decodeText);
    return switch (kind) {
      AvailableRepositoryBranches.kind => AvailableRepositoryBranches(
        runner: readField(fields, 'runner', FileRunner.fromJson),
        branches: readListField(fields, 'branches', decodeText),
        taskBranches: readListField(fields, 'task_branches', decodeText),
      ),
      UnavailableRepositoryBranches.kind => UnavailableRepositoryBranches(
        holders: readListField(fields, 'holders', RepositoryHolder.fromJson),
      ),
      _ => throw FormatException('unknown repository branches $kind'),
    };
  }
}

final class AvailableRepositoryBranches extends RepositoryBranchesView {
  AvailableRepositoryBranches({
    required this.runner,
    required List<String> branches,
    required List<String> taskBranches,
  }) : branches = List<String>.unmodifiable(branches),
       taskBranches = List<String>.unmodifiable(taskBranches);

  static const String kind = 'available';

  final FileRunner runner;
  final List<String> branches;
  final List<String> taskBranches;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      _kindField: kind,
      'runner': runner.toJson(),
      'branches': branches,
      'task_branches': taskBranches,
    };
  }
}

final class UnavailableRepositoryBranches extends RepositoryBranchesView {
  UnavailableRepositoryBranches({required List<RepositoryHolder> holders})
    : holders = List<RepositoryHolder>.unmodifiable(holders);

  static const String kind = 'unavailable';

  final List<RepositoryHolder> holders;

  @override
  JsonObject toJson() {
    return <String, Object?>{_kindField: kind, 'holders': encodeList(holders)};
  }
}

final class FileRunner implements JsonEncodable {
  const FileRunner({required this.deviceId, required this.name});

  factory FileRunner.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return FileRunner(
      deviceId: readField(fields, _deviceIdField, decodeDeviceId),
      name: readField(fields, _nameField, decodeText),
    );
  }

  final DeviceId deviceId;
  final String name;

  @override
  JsonObject toJson() {
    return <String, Object?>{_deviceIdField: deviceId.value, _nameField: name};
  }
}

final class RepositoryHolder implements JsonEncodable {
  const RepositoryHolder({
    required this.deviceId,
    required this.name,
    required this.lastSeen,
  });

  factory RepositoryHolder.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return RepositoryHolder(
      deviceId: readField(fields, _deviceIdField, decodeDeviceId),
      name: readField(fields, _nameField, decodeText),
      lastSeen: readField(fields, 'last_seen', decodeMoment),
    );
  }

  final DeviceId deviceId;
  final String name;
  final DateTime lastSeen;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      _deviceIdField: deviceId.value,
      _nameField: name,
      'last_seen': encodeMoment(lastSeen),
    };
  }
}

enum RepositoryEntryKind implements WireNamed {
  folder('folder'),
  file('file'),
  link('link');

  const RepositoryEntryKind(this.wireName);

  @override
  final String wireName;

  static RepositoryEntryKind decode(Object? json) {
    return decodeWireName(values, json);
  }
}

final class RepositoryEntry implements JsonEncodable {
  const RepositoryEntry({
    required this.name,
    required this.kind,
    required this.size,
  });

  factory RepositoryEntry.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return RepositoryEntry(
      name: readField(fields, _nameField, decodeText),
      kind: readField(fields, _kindField, RepositoryEntryKind.decode),
      size: readOptionalField(fields, _sizeField, decodeInteger),
    );
  }

  final String name;
  final RepositoryEntryKind kind;
  final int? size;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      _nameField: name,
      _kindField: kind.wireName,
      _sizeField: size,
    };
  }
}

final class RepositoryFolderView implements JsonEncodable {
  RepositoryFolderView({required List<RepositoryEntry> entries})
    : entries = List<RepositoryEntry>.unmodifiable(entries);

  factory RepositoryFolderView.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return RepositoryFolderView(
      entries: readListField(fields, 'entries', RepositoryEntry.fromJson),
    );
  }

  final List<RepositoryEntry> entries;

  @override
  JsonObject toJson() => <String, Object?>{'entries': encodeList(entries)};
}

sealed class FilePreview implements JsonEncodable {
  const FilePreview();

  factory FilePreview.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    final String kind = readField(fields, _kindField, decodeText);
    return switch (kind) {
      TextPreview.kind => TextPreview(
        text: readField(fields, 'text', decodeText),
      ),
      ImagePreview.kind => ImagePreview(
        width: readField(fields, 'width', decodeInteger),
        height: readField(fields, 'height', decodeInteger),
        base64Content: readField(fields, 'base64_content', decodeText),
      ),
      TooLargePreview.kind => const TooLargePreview(),
      BinaryPreview.kind => const BinaryPreview(),
      LinkPreview.kind => const LinkPreview(),
      _ => throw FormatException('unknown file preview $kind'),
    };
  }
}

final class TextPreview extends FilePreview {
  const TextPreview({required this.text});

  static const String kind = 'text';

  final String text;

  @override
  JsonObject toJson() => <String, Object?>{_kindField: kind, 'text': text};
}

final class ImagePreview extends FilePreview {
  const ImagePreview({
    required this.width,
    required this.height,
    required this.base64Content,
  });

  static const String kind = 'image';

  final int width;
  final int height;
  final String base64Content;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      _kindField: kind,
      'width': width,
      'height': height,
      'base64_content': base64Content,
    };
  }
}

final class TooLargePreview extends FilePreview {
  const TooLargePreview();

  static const String kind = 'too_large';

  @override
  JsonObject toJson() => <String, Object?>{_kindField: kind};
}

final class BinaryPreview extends FilePreview {
  const BinaryPreview();

  static const String kind = 'binary';

  @override
  JsonObject toJson() => <String, Object?>{_kindField: kind};
}

final class LinkPreview extends FilePreview {
  const LinkPreview();

  static const String kind = 'link';

  @override
  JsonObject toJson() => <String, Object?>{_kindField: kind};
}

final class RepositoryFileView implements JsonEncodable {
  const RepositoryFileView({
    required this.path,
    required this.size,
    required this.preview,
  });

  factory RepositoryFileView.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return RepositoryFileView(
      path: readField(fields, 'path', decodeText),
      size: readField(fields, _sizeField, decodeInteger),
      preview: readField(fields, 'preview', FilePreview.fromJson),
    );
  }

  final String path;
  final int size;
  final FilePreview preview;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'path': path,
      _sizeField: size,
      'preview': preview.toJson(),
    };
  }
}
