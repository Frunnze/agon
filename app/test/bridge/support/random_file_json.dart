import 'dart:convert';
import 'dart:math';

import '../../support/random_inputs.dart';
import 'node_json_primitives.dart';
import 'node_wire_names.dart';

const int _largestImageSide = 8192;

Map<String, Object?> randomFileRunnerJson(Random random) {
  return <String, Object?>{
    'device_id': randomDeviceIdText(random),
    'name': randomText(random),
  };
}

Map<String, Object?> randomRepositoryHolderJson(Random random) {
  return <String, Object?>{
    'device_id': randomDeviceIdText(random),
    'name': randomText(random),
    'last_seen': randomMomentText(random),
  };
}

Map<String, Object?> randomRepositoryBranchesJson(Random random) {
  if (random.nextBool()) {
    return <String, Object?>{
      'kind': 'unavailable',
      'holders': randomListOf(random, randomRepositoryHolderJson),
    };
  }
  return <String, Object?>{
    'kind': 'available',
    'runner': randomFileRunnerJson(random),
    'branches': randomTexts(random),
    'task_branches': randomTexts(random),
  };
}

Map<String, Object?> randomRepositoryEntryJson(Random random) {
  final String kind = pickOne(random, nodeRepositoryEntryKinds);
  final bool isFolder = kind == 'folder';
  return <String, Object?>{
    'name': randomText(random),
    'kind': kind,
    'size': isFolder ? null : randomCount(random),
  };
}

Map<String, Object?> randomRepositoryFolderJson(Random random) {
  return <String, Object?>{
    'entries': randomListOf(random, randomRepositoryEntryJson),
  };
}

Map<String, Object?> randomFilePreviewJson(Random random) {
  final List<Map<String, Object?>> previews = <Map<String, Object?>>[
    <String, Object?>{'kind': 'text', 'text': randomText(random)},
    <String, Object?>{
      'kind': 'image',
      'width': 1 + random.nextInt(_largestImageSide),
      'height': 1 + random.nextInt(_largestImageSide),
      'base64_content': base64Encode(randomBytes(random)),
    },
    <String, Object?>{'kind': 'too_large'},
    <String, Object?>{'kind': 'binary'},
    <String, Object?>{'kind': 'link'},
  ];
  return pickOne(random, previews);
}

Map<String, Object?> randomRepositoryFileJson(Random random) {
  return <String, Object?>{
    'path': randomText(random),
    'size': randomCount(random),
    'preview': randomFilePreviewJson(random),
  };
}
