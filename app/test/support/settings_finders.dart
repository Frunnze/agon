import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/widgets/page_section.dart';

const String _removeLabel = 'Remove';

Finder findWorkspaceDeviceRemoveButtons(String workspaceName) {
  final String membersTitle = 'Devices in $workspaceName';
  final Finder membersSection = find.byWidgetPredicate(
    (Widget widget) => widget is PageSection && widget.title == membersTitle,
  );

  return find.descendant(
    of: membersSection,
    matching: find.text(_removeLabel),
  );
}
