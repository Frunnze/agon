import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/presentation/host_text.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

import '../support/random_inputs.dart';

void main() {
  test('test_segment_host_names_property_rejoins_to_the_input', () {
    final Random random = seededRandom(4101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String text =
          '${randomWordPhrase(random)} huggingface.co '
          '${randomText(random)}';
      final List<TextSegment> segments = segmentHostNames(text);

      expect(segments.map((TextSegment s) => s.text).join(), text);
      expect(
        segments.any(
          (TextSegment s) =>
              s.face == TextFace.monospace && s.text == 'huggingface.co',
        ),
        isTrue,
      );
    }
  });

  test('test_describe_reachable_hosts_property_every_host_in_monospace', () {
    final Random random = seededRandom(4102);
    const List<String> hosts = <String>[
      'api.anthropic.com',
      'github.com',
      'gitlab.com',
      'huggingface.co',
    ];

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> chosen = <String>[
        for (final String host in hosts)
          if (random.nextBool()) host,
      ];
      final List<TextSegment> segments = describeReachableHosts(chosen);
      final List<String> monospaced = <String>[
        for (final TextSegment segment in segments)
          if (segment.face == TextFace.monospace) segment.text,
      ];

      expect(monospaced, chosen);
    }
    expect(
      describeReachableHosts(const <String>['api.anthropic.com', 'github.com'])
          .map((TextSegment s) => s.text)
          .join(),
      'api.anthropic.com through the hub, github.com read-only',
    );
  });

  test('test_describe_network_access_property_local_runs_are_not_limited', () {
    final Random random = seededRandom(4103);
    const List<String> hosts = <String>['api.anthropic.com', 'github.com'];

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> chosen = <String>[
        for (final String host in hosts)
          if (random.nextBool()) host,
      ];
      final SandboxKind sandbox = pickOne(random, SandboxKind.values);

      final String described = describeNetworkAccess(
        sandbox: sandbox,
        allowedHosts: chosen,
      ).map((TextSegment s) => s.text).join();

      final String reachable = describeReachableHosts(chosen)
          .map((TextSegment s) => s.text)
          .join();
      final String expected = sandbox == SandboxKind.localProcess
          ? 'Not limited'
          : '$reachable. Nothing else.';
      expect(described, expected);
    }
  });
}
