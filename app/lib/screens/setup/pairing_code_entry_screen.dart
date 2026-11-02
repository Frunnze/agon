import 'dart:async';

import 'package:flutter/material.dart';

import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/data/qr_code_scanner.dart';
import 'package:agent_orchestration/data/repository/pairing_repository.dart';
import 'package:agent_orchestration/data/rules/pairing_invitation.dart';
import 'package:agent_orchestration/data/rules/setup_input_rules.dart';
import 'package:agent_orchestration/presentation/problem_text.dart';
import 'package:agent_orchestration/screens/pairing.dart';
import 'package:agent_orchestration/screens/setup/server_hosting.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/forms/labelled_text_field.dart';
import 'package:agent_orchestration/widgets/setup_panel.dart';

const String noOtherDevicesText =
    'No other devices yet? Make this computer the server, then pair your '
    'other devices with it.';
const String makeThisComputerTheServerLabel = 'Make this computer the server';
const String _compareWordsText =
    'Your other device shows four words while it asks to approve this one. '
    'Approve there only if they match these, in this order.';
const double _codeLetterSpacing = AppFontSizes.title * AppTracking.codeEm;
final TextStyle _codeInputStyle = AppTextStyles.monospace.copyWith(
  fontSize: AppFontSizes.title,
  letterSpacing: _codeLetterSpacing,
);

class PairingCodeEntryScreen extends StatefulWidget {
  const PairingCodeEntryScreen({
    required this.role,
    required this.deviceKind,
    required this.deviceName,
    required this.scanner,
    required this.hostAppServer,
    required this.pairingRepository,
    required this.navigation,
    super.key,
  });

  final DeviceRole role;
  final String deviceKind;
  final String deviceName;
  final QrCodeScanner? scanner;
  final HostAppServer? hostAppServer;
  final PairingRepository pairingRepository;
  final AppNavigation navigation;

  @override
  State<PairingCodeEntryScreen> createState() =>
      _PairingCodeEntryScreenState();
}

class _PairingCodeEntryScreenState extends State<PairingCodeEntryScreen> {
  final TextEditingController _codeController = TextEditingController();
  String? _scannedServerAddress;
  String? _codeProblem;
  String? _hostingProblem;
  bool _isBusy = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.pairingRepository,
      builder: _buildPanel,
    );
  }

  Widget _buildPanel(BuildContext context, Widget? _) {
    final QrCodeScanner? scanner = widget.scanner;
    final HostAppServer? hostAppServer = widget.hostAppServer;
    final String? hostingProblem = _hostingProblem;
    final WaitingJoin? waitingJoin = widget.pairingRepository
        .findWaitingJoin();

    return SetupPanel(
      step: 'Step 2 of 2',
      title: 'Enter the pairing code',
      children: <Widget>[
        const Text(
          'On a device you already use, open Your devices, then Add device. '
          'It shows a code that works for 5 minutes.',
          style: AppTextStyles.bodyMuted,
        ),
        LabelledTextField(
          label: 'Pairing code',
          hint: 'Dashes and spaces are optional.',
          controller: _codeController,
          problem: _codeProblem,
          style: _codeInputStyle,
          textAlign: TextAlign.center,
        ),
        if (waitingJoin != null) ...<Widget>[
          const Text(_compareWordsText, style: AppTextStyles.smallMuted),
          FingerprintWords(words: waitingJoin.fingerprintWords),
        ],
        SetupActions(
          children: <Widget>[
            if (scanner != null)
              AppButton.secondary(
                label: 'Scan QR code',
                onPressed: () => unawaited(_scan(scanner)),
              ),
            AppButton.primary(
              label: 'Pair this ${widget.deviceKind}',
              onPressed: _isBusy ? null : () => unawaited(_join()),
            ),
            if (hostAppServer != null)
              AppButton.secondary(
                label: makeThisComputerTheServerLabel,
                onPressed: _isBusy
                    ? null
                    : () => unawaited(_host(hostAppServer)),
              ),
          ],
        ),
        if (hostAppServer != null)
          const Text(noOtherDevicesText, style: AppTextStyles.smallMuted),
        if (hostingProblem != null)
          Text(hostingProblem, style: AppTextStyles.smallMuted),
      ],
    );
  }

  Future<void> _scan(QrCodeScanner scanner) async {
    final String? scannedText = await scanner.scanQrCode(context);
    if (scannedText == null) {
      return;
    }

    final PairingInvitation invitation;
    try {
      invitation = decodePairingInvitation(scannedText);
    } on FormatException catch (problem) {
      setState(() => _codeProblem = problem.message);
      return;
    }

    setState(() {
      _codeController.text = invitation.code;
      _scannedServerAddress = invitation.serverAddress;
      _codeProblem = null;
    });
  }

  Future<void> _join() async {
    final String code = _codeController.text;
    final String? codeProblem = describePairingCodeProblem(code);
    setState(() => _codeProblem = codeProblem);
    if (codeProblem != null) {
      return;
    }

    final PairingOutcome? outcome = await _runBusy(
      () => widget.pairingRepository.joinWithCode(
        serverAddress: _scannedServerAddress,
        code: code,
        deviceName: widget.deviceName,
        role: widget.role,
      ),
      showProblem: (String explanation) => _codeProblem = explanation,
    );
    if (outcome != null) {
      widget.navigation.replaceRoute(PairingDoneRoute(outcome));
    }
  }

  Future<void> _host(HostAppServer hostAppServer) async {
    if (_isBusy) {
      return;
    }

    final PairingOutcome? outcome = await _runBusy(
      hostAppServer,
      showProblem: (String explanation) => _hostingProblem = explanation,
    );
    if (outcome != null) {
      widget.navigation.replaceRoute(PairingDoneRoute(outcome));
    }
  }

  Future<PairingOutcome?> _runBusy(
    Future<PairingOutcome> Function() pairing, {
    required void Function(String explanation) showProblem,
  }) async {
    setState(() {
      _isBusy = true;
      _hostingProblem = null;
    });
    try {
      return await pairing();
    } on Object catch (problem) {
      final String? explanation = describeProblemForPeople(problem);
      if (explanation == null) {
        rethrow;
      }
      if (mounted) {
        setState(() => showProblem(explanation));
      }
      return null;
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }
}
