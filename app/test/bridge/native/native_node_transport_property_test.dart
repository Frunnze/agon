import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/native/native_library_source.dart';
import 'package:agent_orchestration/bridge/native/native_node_call.dart';
import 'package:agent_orchestration/bridge/native/native_node_transport.dart';
import 'package:agent_orchestration/bridge/native/node_entry_point.dart';
import 'package:agent_orchestration/bridge/node/node_reply.dart';

import '../../support/random_inputs.dart';
import '../support/hostile_texts.dart';
import 'support/bundled_node_library.dart';

const int _firstSeed = 6270000;
const int _isolateIterations = 40;
const int _largestConcurrentCalls = 12;
const String _missingLibraryPath = 'build/no_such_folder/missing_node.dylib';
const NativeLibrarySource _missingLibrary = LibraryFile(
  path: _missingLibraryPath,
);
const Map<String, Object?> _stoppedReply = <String, Object?>{
  successReplyField: null,
};

String _randomInput(Random random, NodeEntryPoint entryPoint) {
  if (entryPoint == NodeEntryPoint.start) {
    return jsonEncode('${randomHostileText(random)}${random.nextInt(1000)}');
  }
  return randomHostileText(random);
}

JsonObject _readReplyObject(String replyJson) {
  return decodeObject(jsonDecode(replyJson));
}

NativeLibrarySource _randomSource(Random random) {
  final List<NativeLibrarySource> sources = <NativeLibrarySource>[
    const LinkedIntoProcess(),
    LibraryFile(path: randomHostileText(random)),
    LinkedIntoProcessOrLibraryFile(path: randomHostileText(random)),
  ];
  return pickOne(random, sources);
}

void main() {
  final String? skipReason = readBundledLibrarySkipReason();
  final NativeNodeTransport transport = NativeNodeTransport(
    source: bundledLibraryFile(),
  );

  test('test_native_node_transport_constructor_property_keeps_source', () {
    final Random random = seededRandom(_firstSeed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NativeLibrarySource source = _randomSource(random);

      expect(
        identical(NativeNodeTransport(source: source).source, source),
        isTrue,
      );
    }
  });

  test('test_native_node_transport_constructor_property_opens_lazily', () {
    final Random random = seededRandom(_firstSeed + 1);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String path = '$_missingLibraryPath${randomHostileText(random)}';

      expect(
        () => NativeNodeTransport(source: LibraryFile(path: path)),
        returnsNormally,
      );
    }
  });

  test('test_native_node_transport_constructor_property_const_is_shared', () {
    const NativeNodeTransport first = NativeNodeTransport(
      source: _missingLibrary,
    );
    const NativeNodeTransport second = NativeNodeTransport(
      source: _missingLibrary,
    );

    expect(identical(first, second), isTrue);
  });

  test(
    'test_native_node_transport_exchange_property_matches_direct_call',
    () async {
      final Random random = seededRandom(_firstSeed + 2);

      for (int i = 0; i < _isolateIterations; i += 1) {
        final NodeEntryPoint entryPoint = pickOne(
          random,
          NodeEntryPoint.values,
        );
        final String inputJson = _randomInput(random, entryPoint);

        final String isolateReply = await transport.exchange(
          entryPoint: entryPoint,
          inputJson: inputJson,
        );

        expect(
          isolateReply,
          callNodeEntryPoint(
            source: bundledLibraryFile(),
            entryPoint: entryPoint,
            inputJson: inputJson,
          ),
        );
      }
    },
    skip: skipReason,
  );

  test(
    'test_native_node_transport_exchange_property_replies_stay_paired',
    () async {
      final Random random = seededRandom(_firstSeed + 3);

      for (int i = 0; i < _isolateIterations; i += 1) {
        final int callCount = 1 + random.nextInt(_largestConcurrentCalls);
        final List<String> inputs = <String>[];
        for (int call = 0; call < callCount; call += 1) {
          inputs.add(jsonEncode('call $call ${randomHostileText(random)}'));
        }

        final List<String> replies = await Future.wait(<Future<String>>[
          for (final String inputJson in inputs)
            transport.exchange(
              entryPoint: NodeEntryPoint.start,
              inputJson: inputJson,
            ),
        ]);

        for (int call = 0; call < callCount; call += 1) {
          final String alone = await transport.exchange(
            entryPoint: NodeEntryPoint.start,
            inputJson: inputs[call],
          );
          expect(replies[call], alone);
        }
      }
    },
    skip: skipReason,
  );

  test(
    'test_native_node_transport_exchange_property_missing_library',
    () async {
      final Random random = seededRandom(_firstSeed + 4);
      const NativeNodeTransport missingTransport = NativeNodeTransport(
        source: _missingLibrary,
      );

      for (int i = 0; i < _isolateIterations; i += 1) {
        final NodeEntryPoint entryPoint = pickOne(
          random,
          NodeEntryPoint.values,
        );

        await expectLater(
          missingTransport.exchange(
            entryPoint: entryPoint,
            inputJson: _randomInput(random, entryPoint),
          ),
          throwsArgumentError,
        );
      }
    },
  );

  test('test_native_node_transport_stop_property_replies_ok_null', () async {
    for (int i = 0; i < _isolateIterations; i += 1) {
      expect(_readReplyObject(await transport.stop()), _stoppedReply);
    }
  }, skip: skipReason);

  test('test_native_node_transport_stop_property_concurrent_stops', () async {
    final Random random = seededRandom(_firstSeed + 5);

    for (int i = 0; i < _isolateIterations; i += 1) {
      final int stopCount = 1 + random.nextInt(_largestConcurrentCalls);

      final List<String> replies = await Future.wait(<Future<String>>[
        for (int stop = 0; stop < stopCount; stop += 1) transport.stop(),
      ]);

      for (final String reply in replies) {
        expect(_readReplyObject(reply), _stoppedReply);
      }
    }
  }, skip: skipReason);

  test('test_native_node_transport_stop_property_missing_library', () async {
    const NativeNodeTransport missingTransport = NativeNodeTransport(
      source: _missingLibrary,
    );

    for (int i = 0; i < _isolateIterations; i += 1) {
      await expectLater(missingTransport.stop(), throwsArgumentError);
    }
  });
}
