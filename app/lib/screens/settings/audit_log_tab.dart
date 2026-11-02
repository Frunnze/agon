import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/audit.dart';
import 'package:agent_orchestration/data/repository/audit_repository.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/audit_text.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/theme/layout_size.dart';
import 'package:agent_orchestration/theme/page_metrics.dart';
import 'package:agent_orchestration/widgets/empty_state.dart';
import 'package:agent_orchestration/widgets/gaps.dart';
import 'package:agent_orchestration/widgets/lists/list_column.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';
import 'package:agent_orchestration/widgets/lists/list_row_main.dart';
import 'package:agent_orchestration/widgets/lists/responsive_list.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/notice_banner.dart';

const List<String> _columnLabels = <String>[
  'Event',
  'Device',
  'Entry',
  'Time',
];

class AuditLogTab extends StatefulWidget {
  const AuditLogTab({
    required this.auditRepository,
    required this.deviceRepository,
    required this.clock,
    super.key,
  });

  final AuditRepository auditRepository;
  final DeviceRepository deviceRepository;
  final Clock clock;

  @override
  State<AuditLogTab> createState() => _AuditLogTabState();
}

class _AuditLogTabState extends State<AuditLogTab> {
  late Future<ChainSummary> _chainCheck;
  String? _checkedNewestHash;

  @override
  void initState() {
    super.initState();
    _startChainCheck();
    widget.auditRepository.addListener(_recheckGrownLog);
  }

  @override
  void dispose() {
    widget.auditRepository.removeListener(_recheckGrownLog);
    super.dispose();
  }

  void _startChainCheck() {
    _checkedNewestHash = _findNewestHash();
    _chainCheck = widget.auditRepository.verifyChain();
  }

  void _recheckGrownLog() {
    if (_findNewestHash() == _checkedNewestHash) {
      return;
    }
    setState(_startChainCheck);
  }

  String? _findNewestHash() {
    final List<AuditEntry> entries = widget.auditRepository.listEntries();
    if (entries.isEmpty) {
      return null;
    }
    return entries.first.hash;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.auditRepository,
      builder: _buildLog,
    );
  }

  Widget _buildLog(BuildContext context, Widget? _) {
    final List<AuditEntry> entries = widget.auditRepository.listEntries();

    if (entries.isEmpty) {
      return const EmptyState(
        title: 'Nothing logged yet',
        message:
            'Pairings, signed workflows and other changes show up here, each '
            'signed by the device that made it.',
        action: null,
      );
    }

    final DeviceNames deviceNames = DeviceNames(
      widget.deviceRepository.listDevices(),
    );

    final double pageGap = pageGapFor(LayoutSize.of(context));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: spaceVertically(<Widget>[
        FutureBuilder<ChainSummary>(
          future: _chainCheck,
          builder: _buildChainBanner,
        ),
        ResponsiveList(
          columns: buildStandardColumns(_columnLabels),
          rows: <ListRowData>[
            for (final AuditEntry entry in entries)
              _buildRow(entry, deviceNames),
          ],
        ),
      ], pageGap),
    );
  }

  Widget _buildChainBanner(
    BuildContext context,
    AsyncSnapshot<ChainSummary> check,
  ) {
    final ChainSummary? summary = check.data;

    if (check.hasError) {
      return const NoticeBanner(
        tone: BannerTone.danger,
        icon: AppIconKind.alert,
        title: 'The log is broken',
        body: <Widget>[
          Text(
            'An entry does not match the one before it. Someone may have '
            'changed the history.',
          ),
        ],
      );
    }
    if (summary == null) {
      return const NoticeBanner(
        tone: BannerTone.neutral,
        icon: AppIconKind.spinner,
        title: 'Checking the log',
      );
    }

    return NoticeBanner(
      tone: BannerTone.neutral,
      icon: AppIconKind.check,
      title: 'The log is intact',
      body: <Widget>[
        Text(
          '${describeEntryCount(summary.entryCount)}. Each one is signed by '
          'the device that made it, and every device keeps the latest hash.',
        ),
        MixedText(<TextSegment>[
          const TextSegment('Latest '),
          TextSegment.monospace(shortenIdentifier(summary.headHash)),
        ], style: AppTextStyles.bodyMuted),
      ],
    );
  }

  ListRowData _buildRow(AuditEntry entry, DeviceNames deviceNames) {
    return ListRowData(
      key: ValueKey<int>(entry.index),
      main: ListRowMain(
        title: entry.event,
        subtitle: <TextSegment>[TextSegment(entry.detail)],
      ),
      meta: <Widget>[
        Text(
          deviceNames.describeDevice(entry.deviceId),
          style: AppTextStyles.monospace,
        ),
        Text(shortenIdentifier(entry.hash), style: AppTextStyles.monospace),
      ],
      end: Text(
        describeAuditTime(entry.at, widget.clock.now()),
        style: AppTextStyles.bodyMuted,
      ),
    );
  }
}
