import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/compact_page_header.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

class BuilderHeader extends StatelessWidget {
  const BuilderHeader({
    required this.title,
    required this.summary,
    required this.onBack,
    required this.onCancel,
    required this.onSigned,
    super.key,
  });

  final String title;
  final String summary;
  final VoidCallback onBack;
  final VoidCallback onCancel;
  final VoidCallback onSigned;

  @override
  Widget build(BuildContext context) {
    return CompactPageHeader(
      title: title,
      summary: summary,
      backLink: BackLink(label: 'Workflows', onPressed: onBack),
      actions: <Widget>[
        AppButton.secondary(label: 'Cancel', onPressed: onCancel),
        AppButton.primary(label: 'Sign and save', onPressed: onSigned),
      ],
    );
  }
}
