import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_audit.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/audit.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/repository/audit_repository.dart';
import 'package:agent_orchestration/presentation/audit_text.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../bridge/support/node_json_primitives.dart';
import '../support/app_harness.dart';
import '../support/random_inputs.dart';

final class _GrowingAuditRepository extends ChangeNotifier
    implements AuditRepository {
  List<AuditEntry> _entries = galleryAuditEntries;

  @override
  List<AuditEntry> listEntries() => _entries;

  @override
  Future<ChainSummary> verifyChain() async {
    return ChainSummary(
      entryCount: _entries.length,
      headHash: _entries.first.hash,
    );
  }

  void addNewest(AuditEntry entry) {
    _entries = List<AuditEntry>.unmodifiable(<AuditEntry>[entry, ..._entries]);
    notifyListeners();
  }
}

AuditEntry _buildNewestEntry(
  Random random, {
  required int index,
  required DeviceId deviceId,
}) {
  return AuditEntry(
    index: index,
    at: galleryNow,
    deviceId: deviceId,
    event: 'Event $index ${randomWordPhrase(random)}',
    detail: '',
    previousHash: randomDeviceIdText(random),
    hash: randomDeviceIdText(random),
  );
}

String _describeShownChain(int entryCount) {
  return '${describeEntryCount(entryCount)}. Each one is signed by '
      'the device that made it, and every device keeps the latest hash.';
}

String _readShownLatestHash(WidgetTester tester) {
  final Text latestText = tester.widget<Text>(find.textContaining('Latest '));
  return latestText.textSpan!.toPlainText();
}

Future<_GrowingAuditRepository> _openAuditLog(WidgetTester tester) async {
  final _GrowingAuditRepository audit = _GrowingAuditRepository();
  final AppDependencies dependencies = replaceRepositories(
    buildGalleryDependencies(),
    auditRepository: audit,
  );
  await pumpApp(
    tester,
    size: desktopSize,
    route: const SectionRoute(AppSection.settings),
    dependencies: dependencies,
  );
  await tester.tap(find.text('Audit log'));
  await pumpFrames(tester);
  return audit;
}

void main() {
  testWidgets('test_audit_log_tab_property_rows_follow_the_repository', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9471);
    final _GrowingAuditRepository audit = await _openAuditLog(tester);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final bool isKnownDevice = random.nextBool();
      final DeviceId deviceId = isKnownDevice
          ? GalleryDeviceIds.airLaptop
          : DeviceId(randomDeviceIdText(random));
      final AuditEntry entry = _buildNewestEntry(
        random,
        index: galleryAuditEntryCount + i,
        deviceId: deviceId,
      );

      audit.addNewest(entry);
      await pumpFrames(tester);

      expect(find.text(entry.event), findsOneWidget);
      expect(find.text(shortenIdentifier(entry.hash)), findsOneWidget);
      if (!isKnownDevice) {
        expect(find.text(shortenIdentifier(deviceId.value)), findsWidgets);
      }
    }
  });

  testWidgets('test_audit_log_tab_property_chain_banner_follows_the_log', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9472);
    final _GrowingAuditRepository audit = await _openAuditLog(tester);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AuditEntry entry = _buildNewestEntry(
        random,
        index: galleryAuditEntryCount + i,
        deviceId: GalleryDeviceIds.airLaptop,
      );

      audit.addNewest(entry);
      await pumpFrames(tester);

      final int entryCount = audit.listEntries().length;
      expect(find.text(_describeShownChain(entryCount)), findsOneWidget);
      expect(
        _readShownLatestHash(tester),
        'Latest ${shortenIdentifier(entry.hash)}',
      );
    }
  });
}
