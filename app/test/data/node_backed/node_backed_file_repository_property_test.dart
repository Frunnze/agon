import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../bridge/support/random_file_json.dart';
import '../../bridge/support/random_typed_values.dart';
import '../../bridge/support/scripted_node_transport.dart';
import '../../support/random_inputs.dart';

typedef _ReplyMaker = JsonObject Function(Random random);

const Map<String, PreviewUnavailableReason> _unavailableReasons =
    <String, PreviewUnavailableReason>{
      'too_large': PreviewUnavailableReason.tooLarge,
      'binary': PreviewUnavailableReason.binary,
      'link': PreviewUnavailableReason.link,
    };
const Map<String, RepositoryEntryKind> _entryKinds =
    <String, RepositoryEntryKind>{
      'folder': RepositoryEntryKind.folder,
      'file': RepositoryEntryKind.file,
      'link': RepositoryEntryKind.link,
    };

final class _FreshReplyNode {
  _FreshReplyNode({required this.random, required this.makeReply});

  final Random random;
  final _ReplyMaker makeReply;
  final List<JsonObject> replies = <JsonObject>[];
  final List<String> commandNames = <String>[];

  late final NodeCommandChannel channel = NodeCommandChannel(
    transport: ScriptedNodeTransport(answer: answer),
  );

  String answer(String inputJson) {
    final JsonObject command = decodeObject(jsonDecode(inputJson));
    commandNames.add(command['command']! as String);
    final JsonObject reply = makeReply(random);
    replies.add(reply);
    return encodeSuccessReply(reply);
  }
}

RepositoryBranchLocation _randomLocation(Random random) {
  return RepositoryBranchLocation(
    projectId: randomProjectId(random),
    repositoryAddress: randomText(random),
    runnerId: randomDeviceId(random),
    branch: randomText(random),
  );
}

List<Object?> _describeHolderJson(Object? holder) {
  final JsonObject fields = holder! as JsonObject;
  return <Object?>[fields['device_id'], fields['name']];
}

List<Object?> _describeEntryJson(Object? entry) {
  final JsonObject fields = entry! as JsonObject;
  return <Object?>[
    fields['name'],
    _entryKinds[fields['kind']],
    fields['size'],
  ];
}

void _expectSourceOfReply(RepositoryFileSource source, JsonObject reply) {
  switch (source) {
    case FilesFromRunner():
      final JsonObject runner = reply['runner']! as JsonObject;
      expect(reply['kind'], 'available');
      expect(source.runnerId.value, runner['device_id']);
      expect(source.runnerName, runner['name']);
      expect(source.branches, reply['branches']);
      expect(source.taskBranches, reply['task_branches']);
    case FilesWithoutRunner():
      final List<Object?> holders = reply['holders']! as List<Object?>;
      expect(reply['kind'], 'unavailable');
      expect(
        <Object?>[
          for (final RepositoryHolder holder in source.holders)
            <Object?>[holder.deviceId.value, holder.name],
        ],
        <Object?>[
          for (final Object? holder in holders) _describeHolderJson(holder),
        ],
      );
  }
}

void _expectPreviewOfReply(FilePreview preview, JsonObject reply) {
  final Object? kind = reply['kind'];
  switch (preview) {
    case TextFilePreview(:final String text):
      expect(kind, 'text');
      expect(text, reply['text']);
    case ImageFilePreview():
      expect(kind, 'image');
      expect(preview.width, reply['width']);
      expect(preview.height, reply['height']);
      expect(preview.bytes, base64Decode(reply['base64_content']! as String));
    case UnavailableFilePreview(:final PreviewUnavailableReason reason):
      expect(reason, _unavailableReasons[kind]);
  }
}

void main() {
  test(
    'test_node_backed_file_repository_constructor_property_keeps_channel',
    () {
      final Random random = seededRandom(77001);
      for (int i = 0; i < propertyIterations; i += 1) {
        final _FreshReplyNode freshNode = _FreshReplyNode(
          random: random,
          makeReply: randomRepositoryFolderJson,
        );

        final NodeBackedFileRepository repository = NodeBackedFileRepository(
          channel: freshNode.channel,
        );

        expect(repository.channel, same(freshNode.channel));
        expect(freshNode.commandNames, isEmpty);
      }
    },
  );

  test(
    'test_node_backed_file_repository_constructor_property_own_channel',
    () async {
      final Random random = seededRandom(77002);
      for (int i = 0; i < propertyIterations; i += 1) {
        final _FreshReplyNode asked = _FreshReplyNode(
          random: random,
          makeReply: randomRepositoryFolderJson,
        );
        final _FreshReplyNode other = _FreshReplyNode(
          random: random,
          makeReply: randomRepositoryFolderJson,
        );
        final NodeBackedFileRepository idle = NodeBackedFileRepository(
          channel: other.channel,
        );

        await NodeBackedFileRepository(channel: asked.channel)
            .listFolder(location: _randomLocation(random), folder: '');

        expect(asked.commandNames, <String>['list_repository_files']);
        expect(other.commandNames, isEmpty);
        expect(idle.channel, same(other.channel));
      }
    },
  );

  test(
    'test_node_backed_file_repository_constructor_property_never_caches',
    () async {
      final Random random = seededRandom(77003);
      for (int i = 0; i < propertyIterations; i += 1) {
        final _FreshReplyNode freshNode = _FreshReplyNode(
          random: random,
          makeReply: randomRepositoryFileJson,
        );
        final NodeBackedFileRepository repository = NodeBackedFileRepository(
          channel: freshNode.channel,
        );
        final RepositoryBranchLocation location = _randomLocation(random);

        final RepositoryFile first = await repository.readFile(
          location: location,
          path: 'a',
        );
        final RepositoryFile second = await repository.readFile(
          location: location,
          path: 'a',
        );

        expect(freshNode.commandNames.length, 2);
        expect(first.path, freshNode.replies.first['path']);
        expect(second.path, freshNode.replies.last['path']);
      }
    },
  );

  test(
    'test_open_repository_property_keeps_every_branch_and_holder',
    () async {
      final Random random = seededRandom(77004);
      for (int i = 0; i < propertyIterations; i += 1) {
        final _FreshReplyNode freshNode = _FreshReplyNode(
          random: random,
          makeReply: randomRepositoryBranchesJson,
        );

        final RepositoryFileSource source =
            await NodeBackedFileRepository(channel: freshNode.channel)
                .openRepository(
                  projectId: randomProjectId(random),
                  repositoryAddress: randomText(random),
                  preferredRunnerId: null,
                );

        _expectSourceOfReply(source, freshNode.replies.single);
      }
    },
  );

  test('test_list_folder_property_keeps_entries_in_node_order', () async {
    final Random random = seededRandom(77005);
    for (int i = 0; i < propertyIterations; i += 1) {
      final _FreshReplyNode freshNode = _FreshReplyNode(
        random: random,
        makeReply: randomRepositoryFolderJson,
      );

      final List<RepositoryEntry> entries = await NodeBackedFileRepository(
        channel: freshNode.channel,
      ).listFolder(location: _randomLocation(random), folder: 'src');

      final List<Object?> wire =
          freshNode.replies.single['entries']! as List<Object?>;
      expect(
        <Object?>[
          for (final RepositoryEntry entry in entries)
            <Object?>[entry.name, entry.kind, entry.size],
        ],
        <Object?>[for (final Object? entry in wire) _describeEntryJson(entry)],
      );
    }
  });

  test('test_list_folder_property_listing_cannot_be_changed', () async {
    final Random random = seededRandom(77006);
    for (int i = 0; i < propertyIterations; i += 1) {
      final _FreshReplyNode freshNode = _FreshReplyNode(
        random: random,
        makeReply: randomRepositoryFolderJson,
      );

      final List<RepositoryEntry> entries = await NodeBackedFileRepository(
        channel: freshNode.channel,
      ).listFolder(location: _randomLocation(random), folder: '');

      expect(
        () => entries.add(
          const RepositoryEntry(
            name: 'x',
            kind: RepositoryEntryKind.file,
            size: 1,
          ),
        ),
        throwsUnsupportedError,
      );
      expect(entries.clear, throwsUnsupportedError);
    }
  });

  test('test_read_file_property_preview_matches_the_reply', () async {
    final Random random = seededRandom(77007);
    for (int i = 0; i < propertyIterations; i += 1) {
      final _FreshReplyNode freshNode = _FreshReplyNode(
        random: random,
        makeReply: randomRepositoryFileJson,
      );

      final RepositoryFile file = await NodeBackedFileRepository(
        channel: freshNode.channel,
      ).readFile(location: _randomLocation(random), path: randomText(random));

      final JsonObject reply = freshNode.replies.single;
      expect(file.size, reply['size']);
      _expectPreviewOfReply(file.preview, reply['preview']! as JsonObject);
    }
  });
}
