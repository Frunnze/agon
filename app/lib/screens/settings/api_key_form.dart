import 'dart:async';

import 'package:flutter/material.dart';

import 'package:agent_orchestration/presentation/agent_login_text.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/forms/form_field_block.dart';
import 'package:agent_orchestration/widgets/gaps.dart';

class ApiKeyForm extends StatefulWidget {
  const ApiKeyForm({required this.onSave, required this.onCancel, super.key});

  final Future<void> Function(String apiKey) onSave;
  final VoidCallback onCancel;

  @override
  State<ApiKeyForm> createState() => _ApiKeyFormState();
}

class _ApiKeyFormState extends State<ApiKeyForm> {
  final TextEditingController _keyController = TextEditingController();

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: spaceVertically(<Widget>[
        FormFieldBlock(
          label: apiKeyFieldLabel,
          hint: apiKeyHint,
          children: <Widget>[
            TextField(
              controller: _keyController,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              style: AppTextStyles.body.merge(AppTextStyles.monospace),
              onSubmitted: (String _) => unawaited(_save()),
            ),
          ],
        ),
        Wrap(
          spacing: AppSpacing.space2,
          runSpacing: AppSpacing.space2,
          children: <Widget>[
            AppButton.primary(
              label: saveKeyLabel,
              onPressed: () => unawaited(_save()),
            ),
            AppButton.secondary(
              label: cancelLabel,
              onPressed: widget.onCancel,
            ),
          ],
        ),
      ], AppSpacing.space3),
    );
  }

  Future<void> _save() async {
    await widget.onSave(_keyController.text);
  }
}
