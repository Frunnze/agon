import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/agent_login.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/repository/agent_login_repository.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/agent_login_text.dart';
import 'package:agent_orchestration/screens/runners/api_key_form.dart';
import 'package:agent_orchestration/screens/runners/login_terminal_panel.dart';
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
            onType: widget.repository.typeIntoTerminal,
            onClose: () => unawaited(widget.repository.closeTerminal()),
          )
        else if (_isAskingForApiKey)
          ApiKeyForm(onSave: _saveApiKey, onCancel: _closeApiKeyForm)
        else if (actions.isNotEmpty)
          Wrap(
            spacing: AppSpacing.space2,
            runSpacing: AppSpacing.space2,
            children: <Widget>[
              for (final AgentLoginAction action in actions)
                _buildActionButton(action),
            ],
          ),
      ],
    );
  }

  Widget _buildActionButton(AgentLoginAction action) {
    final String label = describeAgentLoginAction(action);
    return switch (action) {
      AgentLoginAction.logIn => AppButton.primary(
        label: label,
        onPressed: () => _openTerminal(AgentPlace.localProcess),
      ),
      AgentLoginAction.connect => AppButton.primary(
        label: label,
        icon: AppIconKind.terminal,
        onPressed: () => _openTerminal(AgentPlace.container),
      ),
      AgentLoginAction.useApiKey => AppButton.secondary(
        label: label,
        onPressed: _openApiKeyForm,
      ),
      AgentLoginAction.disconnect => AppButton.secondary(
        label: label,
        onPressed: () => unawaited(widget.repository.forgetCredential()),
      ),
    };
  }

  void _openTerminal(AgentPlace place) {
    unawaited(widget.repository.openTerminal(place));
  }

  void _openApiKeyForm() {
    setState(() => _isAskingForApiKey = true);
  }

  void _closeApiKeyForm() {
    setState(() => _isAskingForApiKey = false);
  }

  Future<void> _saveApiKey(String apiKey) async {
    await widget.repository.saveApiKey(apiKey);
    if (mounted) {
      _closeApiKeyForm();
    }
  }
}
