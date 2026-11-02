import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/presentation/time_phrases.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

const String _preface =
    "Files come from a runner's copy of the repository, so the app server "
    'never sees your code.';
const String _openingPromise = 'The files open here as soon as one is online.';
const String _listSeparator = ', ';
const String _lastListSeparator = ' and ';

String describeNoRunnerTitle(String repositoryPath) {
  return 'No runner with $repositoryPath is online';
}

List<TextSegment> describeNoRunnerExplanation({
  required List<RepositoryHolder> holders,
  required String repositoryPath,
  required DateTime now,
}) {
  if (holders.isEmpty) {
    return <TextSegment>[
      TextSegment('$_preface No runner has a copy of $repositoryPath yet.'),
    ];
  }

  final String seenPhrase = _describeLastSeen(holders, now);
  if (holders.length == 1) {
    return <TextSegment>[
      const TextSegment('$_preface Only '),
      TextSegment.monospace(holders.single.name),
      TextSegment(
        ' has a copy of $repositoryPath, and it was last seen $seenPhrase.',
      ),
    ];
  }

  return <TextSegment>[
    const TextSegment('$_preface '),
    ..._listHolderNames(holders),
    TextSegment(
      ' have a copy of $repositoryPath, and the last of them was seen '
      '$seenPhrase.',
    ),
  ];
}

String describeNoRunnerAdvice({
  required int holderCount,
  required String repositoryPath,
}) {
  if (holderCount == 0) {
    return 'Start a task on $repositoryPath so a runner makes a copy. '
        '$_openingPromise';
  }

  final String turnOn = holderCount == 1 ? 'Turn it on' : 'Turn one on';
  return '$turnOn, or start a task on $repositoryPath so another runner '
      'makes a copy. $_openingPromise';
}

List<TextSegment> _listHolderNames(List<RepositoryHolder> holders) {
  final List<TextSegment> segments = <TextSegment>[];

  for (int index = 0; index < holders.length; index += 1) {
    if (index == holders.length - 1) {
      segments.add(const TextSegment(_lastListSeparator));
    } else if (index > 0) {
      segments.add(const TextSegment(_listSeparator));
    }
    segments.add(TextSegment.monospace(holders[index].name));
  }

  return segments;
}

String _describeLastSeen(List<RepositoryHolder> holders, DateTime now) {
  DateTime mostRecent = holders.first.lastSeen;
  for (final RepositoryHolder holder in holders) {
    if (holder.lastSeen.isAfter(mostRecent)) {
      mostRecent = holder.lastSeen;
    }
  }

  final String phrase = describeTimeSince(mostRecent, now);
  return '${phrase[0].toLowerCase()}${phrase.substring(1)}';
}
