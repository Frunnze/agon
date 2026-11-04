import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/widgets/page_section.dart';

const String _removeLabel = 'Remove';

Finder _findWorkspaceDevicesSection(String workspaceName) {
  final String membersTitle = 'In $workspaceName';
  return find.byWidgetPredicate(
    (Widget widget) => widget is PageSection && widget.title == membersTitle,
  );
}

Finder findWorkspaceDeviceRemoveButtons(String workspaceName) {
  return find.descendant(
    of: _findWorkspaceDevicesSection(workspaceName),
    matching: find.text(_removeLabel),
  );
}

Finder findWorkspaceDevice({
  required String workspaceName,
  required String deviceName,
}) {
  return find.descendant(
    of: _findWorkspaceDevicesSection(workspaceName),
    matching: find.text(deviceName),
  );
}
