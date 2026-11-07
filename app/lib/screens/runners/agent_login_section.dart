import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/agent_login.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/repository/agent_login_repository.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/agent_login_text.dart';
import 'package:agent_orchestration/screens/runners/api_key_form.dart';
import 'package:agent_orchestration/screens/runners/login_terminal_panel.dart';
import 'package:agent_orchestration/screens/shared/action_refusal.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/page_section.dart';
import 'package:agent_orchestration/widgets/status_label.dart';

class AgentLoginSection extends StatefulWidget {
  const AgentLoginSection({
    required this.place,
    required this.repository,
    super.key,
  });

  final AgentPlace place;
  final AgentLoginRepository repository;

  @override
  State<AgentLoginSection> createState() => _AgentLoginSectionState();
}

class _AgentLoginSectionState extends State<AgentLoginSection> {
  bool _isAskingForApiKey = false;

  @override
  void initState() {
    super.initState();
    unawaited(widget.repository.checkStatus());
  }

  @override
  void dispose() {
    if (_findOwnTerminal() != null) {
      unawaited(widget.repository.closeTerminal());
    }
    super.dispose();
  }

  LoginTerminal? _findOwnTerminal() {
    final LoginTerminal? terminal = widget.repository.findTerminal();
    if (terminal == null || terminal.place != widget.place) {
      return null;
    }
    return terminal;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.repository,
      builder: _buildSection,
    );
  }

  Widget _buildSection(BuildContext context, Widget? _) {
    final AgentLoginStatus? status = widget.repository.findStatus();
    if (status == null) {
      return const SizedBox.shrink();
    }

    final AgentLoginDescription description = describeAgentLogin(
      place: widget.place,
      status: status,
    );
    final LoginTerminal? terminal = _findOwnTerminal();
    final List<AgentLoginAction> actions = chooseAgentLoginActions(
      place: widget.place,
      status: status,
    );

    return PageSection(
      title: describeAgentLoginTitle(widget.place),
      actions: <Widget>[
        StatusLabel(
          text: description.statusText,
          tone: description.isReady ? StatusTone.normal : StatusTone.attention,
          icon: description.isReady ? AppIconKind.check : AppIconKind.alert,
        ),
      ],
      children: <Widget>[
        Text(description.detail, style: AppTextStyles.bodyMuted),
        if (terminal != null)
          LoginTerminalPanel(
            terminal: terminal,
            onType: (String keys) => _typeIntoTerminal(context, keys),
            onClose: () => unawaited(_closeTerminal(context)),
          )
        else if (_isAskingForApiKey)
          ApiKeyForm(
            onSave: (String apiKey) => _saveApiKey(context, apiKey),
            onCancel: _closeApiKeyForm,
          )
        else if (actions.isNotEmpty)
          Wrap(
            spacing: AppSpacing.space2,
            runSpacing: AppSpacing.space2,
            children: <Widget>[
              for (final AgentLoginAction action in actions)
                _buildActionButton(context, action),
            ],
          ),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, AgentLoginAction action) {
    final String label = describeAgentLoginAction(action);
    return switch (action) {
      AgentLoginAction.logIn => AppButton.primary(
        label: label,
        onPressed: () => unawaited(
          _openTerminal(context, label: label, place: AgentPlace.localProcess),
        ),
      ),
      AgentLoginAction.connect => AppButton.primary(
        label: label,
        icon: AppIconKind.terminal,
        onPressed: () => unawaited(
          _openTerminal(context, label: label, place: AgentPlace.container),
        ),
      ),
      AgentLoginAction.useApiKey => AppButton.secondary(
        label: label,
        onPressed: _openApiKeyForm,
      ),
      AgentLoginAction.disconnect => AppButton.secondary(
        label: label,
        onPressed: () => unawaited(_forgetCredential(context, label)),
      ),
    };
  }

  Future<ActionOutcome> _runLoginAction(
    BuildContext context, {
    required String actionLabel,
    required PersonAction action,
  }) {
    return runShowingRefusal(
      context: context,
      title: describeAgentLoginTitle(widget.place),
      actionLabel: actionLabel,
      action: action,
    );
  }

  Future<void> _openTerminal(
    BuildContext context, {
    required String label,
    required AgentPlace place,
  }) {
    return _runLoginAction(
      context,
      actionLabel: label,
      action: () => widget.repository.openTerminal(place),
    );
  }

  Future<void> _forgetCredential(BuildContext context, String label) {
    return _runLoginAction(
      context,
      actionLabel: label,
      action: widget.repository.forgetCredential,
    );
  }

  Future<void> _typeIntoTerminal(BuildContext context, String keys) {
    return _runLoginAction(
      context,
      actionLabel: sendLabel,
      action: () => widget.repository.typeIntoTerminal(keys),
    );
  }

  Future<void> _closeTerminal(BuildContext context) {
    return _runLoginAction(
      context,
      actionLabel: closeLabel,
      action: widget.repository.closeTerminal,
    );
  }

  void _openApiKeyForm() {
    setState(() => _isAskingForApiKey = true);
  }

  void _closeApiKeyForm() {
    setState(() => _isAskingForApiKey = false);
  }

  Future<void> _saveApiKey(BuildContext context, String apiKey) async {
    final ActionOutcome outcome = await _runLoginAction(
      context,
      actionLabel: saveKeyLabel,
      action: () => widget.repository.saveApiKey(apiKey),
    );
    if (outcome == ActionOutcome.done && mounted) {
      _closeApiKeyForm();
    }
  }
}
