import 'dart:async';

import 'package:flutter/material.dart';

import 'package:agent_orchestration/data/biometric_confirmation.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';
import 'package:agent_orchestration/data/repository/pairing_repository.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/device_text.dart';
import 'package:agent_orchestration/presentation/scope_catalog.dart';
import 'package:agent_orchestration/screens/pairing.dart';
import 'package:agent_orchestration/screens/shared/runner_link_route.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/app_page.dart';
import 'package:agent_orchestration/widgets/fact_list.dart';
import 'package:agent_orchestration/widgets/forms/form_field_block.dart';
import 'package:agent_orchestration/widgets/forms/tag_input_field.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/page_header.dart';
import 'package:agent_orchestration/widgets/page_section.dart';

class PairingApprovalScreen extends StatefulWidget {
  const PairingApprovalScreen({
    required this.pairingRepository,
    required this.deviceRepository,
    required this.workspaceRepository,
    required this.biometricConfirmation,
    required this.navigation,
    super.key,
  });

  final PairingRepository pairingRepository;
  final DeviceRepository deviceRepository;
  final WorkspaceRepository workspaceRepository;
  final BiometricConfirmation biometricConfirmation;
  final AppNavigation navigation;

  @override
  State<PairingApprovalScreen> createState() => _PairingApprovalScreenState();
}

class _PairingApprovalScreenState extends State<PairingApprovalScreen> {
  late List<WorkspaceId> _workspaceIds = <WorkspaceId>[
    widget.workspaceRepository.currentWorkspace().id,
  ];
  bool _showsProblems = false;
  bool _isDeciding = false;

  @override
  Widget build(BuildContext context) {
    final PairingRequest? request = widget.pairingRepository
        .findPendingRequest();
    final BackLink backLink = BackLink(
      label: 'Your devices',
      onPressed: _returnToDevices,
    );

    if (request == null) {
      return AppPage(
        children: <Widget>[
          PageHeader(
            title: 'No device is waiting',
            backLink: backLink,
            summary: const <TextSegment>[
              TextSegment('Show a pairing code to add a device.'),
            ],
          ),
        ],
      );
    }

    return AppPage(
      children: <Widget>[
        PageHeader(
          title: 'Approve ${request.deviceName}?',
          backLink: backLink,
          summary: <TextSegment>[
            TextSegment(
              'It wants to join as ${describeRoleWithArticle(request.role)}.',
            ),
          ],
        ),
        buildPairingLinkRoute(
          startName: request.deviceName,
          endName: widget.deviceRepository.currentDevice().name,
          link: request.link,
        ),
        FormColumn(
          children: <Widget>[
            PageSection(
              title: '1. Check the words',
              children: <Widget>[
                Text(
                  '${request.deviceName} shows four words. Approve only if '
                  'they match these, in this order.',
                ),
                FingerprintWords(words: request.fingerprintWords),
              ],
            ),
            PageSection(
              title: '2. Check the request',
              children: <Widget>[_buildRequestFacts(request)],
            ),
            PageSection(
              title: '3. Choose where it works',
              children: <Widget>[_buildWorkspaceField()],
            ),
            Wrap(
              spacing: AppSpacing.space2,
              runSpacing: AppSpacing.space2,
              children: <Widget>[
                AppButton.secondary(
                  label: 'Reject',
                  onPressed: _isDeciding ? null : () => unawaited(_reject()),
                ),
                AppButton.primary(
                  label:
                      'Approve with '
                      '${widget.biometricConfirmation.methodName}',
                  icon: AppIconKind.fingerprint,
                  onPressed: _isDeciding ? null : () => unawaited(_approve()),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRequestFacts(PairingRequest request) {
    return FactRow(
      facts: <Fact>[
        Fact(
          term: 'Role',
          description: <TextSegment>[TextSegment(request.role.label)],
        ),
        Fact(
          term: 'Hardware key',
          description: <TextSegment>[TextSegment(request.keyKind.label)],
        ),
        Fact(
          term: 'Code used',
          description: <TextSegment>[TextSegment.monospace(request.codeUsed)],
        ),
      ],
    );
  }

  ScopeCatalog _buildWorkspaceCatalog() {
    return ScopeCatalog(
      workspaces: widget.workspaceRepository.listWorkspaces(),
      projects: const <Project>[],
    );
  }

  Widget _buildWorkspaceField() {
    final ScopeCatalog catalog = _buildWorkspaceCatalog();
    final bool showsProblem = _showsProblems && _workspaceIds.isEmpty;

    return FormFieldBlock(
      label: 'Workspaces',
      children: <Widget>[
        TagInputField(
          tags: <String>[
            for (final WorkspaceId workspaceId in _workspaceIds)
              catalog.nameOfWorkspace(workspaceId),
          ],
          suggestions: <String>[
            for (final Workspace workspace in catalog.workspaces)
              workspace.name,
          ],
          placeholder: 'Add a workspace',
          onTagAdded: _addWorkspace,
          onTagRemoved: _removeWorkspace,
        ),
        if (showsProblem)
          Text(
            'Choose at least one workspace',
            style: AppTextStyles.small.copyWith(color: AppColors.danger),
          ),
      ],
    );
  }

  void _addWorkspace(String workspaceName) {
    final WorkspaceId workspaceId = _buildWorkspaceCatalog().findWorkspaceId(
      workspaceName,
    );
    if (_workspaceIds.contains(workspaceId)) {
      return;
    }

    setState(
      () => _workspaceIds = <WorkspaceId>[..._workspaceIds, workspaceId],
    );
  }

  void _removeWorkspace(String workspaceName) {
    final WorkspaceId workspaceId = _buildWorkspaceCatalog().findWorkspaceId(
      workspaceName,
    );
    final List<WorkspaceId> remaining = <WorkspaceId>[
      for (final WorkspaceId candidate in _workspaceIds)
        if (candidate != workspaceId) candidate,
    ];

    setState(() => _workspaceIds = remaining);
  }

  void _returnToDevices() {
    widget.navigation.openSection(const SectionRoute(AppSection.devices));
  }

  Future<void> _reject() async {
    setState(() => _isDeciding = true);
    try {
      await widget.pairingRepository.rejectPairing();
      _returnToDevices();
    } finally {
      _stopDeciding();
    }
  }

  Future<void> _approve() async {
    if (_workspaceIds.isEmpty) {
      setState(() => _showsProblems = true);
      return;
    }

    setState(() => _isDeciding = true);
    try {
      await _confirmAndApprove();
    } finally {
      _stopDeciding();
    }
  }

  Future<void> _confirmAndApprove() async {
    final bool isConfirmed = await widget.biometricConfirmation.confirm(
      reason: 'Approve a new device',
    );
    if (!isConfirmed) {
      return;
    }

    await widget.pairingRepository.approvePairing(_workspaceIds);
    _returnToDevices();
  }

  void _stopDeciding() {
    if (mounted) {
      setState(() => _isDeciding = false);
    }
  }
}
