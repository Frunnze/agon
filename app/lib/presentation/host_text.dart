import 'package:agent_orchestration/widgets/mixed_text.dart';

const TextSegment _nothingElseSegment = TextSegment('. Nothing else.');

final RegExp _hostNamePattern = RegExp(
  r'\b[a-z0-9-]+(?:\.[a-z0-9-]+)*\.[a-z]{2,}\b',
);

const Set<String> _repositoryHosts = <String>{
  'github.com',
  'gitlab.com',
  'bitbucket.org',
};

List<TextSegment> segmentHostNames(String text) {
  final List<TextSegment> segments = <TextSegment>[];
  int consumedUntil = 0;

  for (final RegExpMatch match in _hostNamePattern.allMatches(text)) {
    if (match.start > consumedUntil) {
      segments.add(TextSegment(text.substring(consumedUntil, match.start)));
    }
    segments.add(TextSegment.monospace(match.group(0)!));
    consumedUntil = match.end;
  }
  if (consumedUntil < text.length) {
    segments.add(TextSegment(text.substring(consumedUntil)));
  }

  return segments;
}

List<TextSegment> describeReachableHosts(List<String> hosts) {
  final List<TextSegment> segments = <TextSegment>[];

  for (final String host in hosts) {
    if (segments.isNotEmpty) {
      segments.add(const TextSegment(', '));
    }
    segments.add(TextSegment.monospace(host));
    if (_repositoryHosts.contains(host)) {
      segments.add(const TextSegment(' read-only'));
    } else {
      segments.add(const TextSegment(' through the hub'));
    }
  }

  return segments;
}

List<TextSegment> describeContainerNetwork(List<String> allowedHosts) {
  return <TextSegment>[
    ...describeReachableHosts(allowedHosts),
    _nothingElseSegment,
  ];
}
