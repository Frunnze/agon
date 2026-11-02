import 'package:flutter/material.dart';

import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/app_dialog.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';
import 'package:agent_orchestration/widgets/lists/list_row_main.dart';
import 'package:agent_orchestration/widgets/lists/responsive_list.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

Future<DeviceId?> showAddWorkspaceDeviceDialog({
  required BuildContext context,
  required String workspaceName,
  required List<Device> candidates,
}) {
  return showAppDialog<DeviceId>(
    context: context,
    builder: (BuildContext _) => AddWorkspaceDeviceDialog(
      workspaceName: workspaceName,
      candidates: candidates,
    ),
  );
}

class AddWorkspaceDeviceDialog extends StatelessWidget {
  const AddWorkspaceDeviceDialog({
    required this.workspaceName,
    required this.candidates,
    super.key,
  });

  final String workspaceName;
  final List<Device> candidates;

  @override
  Widget build(BuildContext context) {
    final NavigatorState navigator = Navigator.of(context);

    return AppDialog(
      title: 'Add a device to $workspaceName',
      content: <Widget>[
        if (candidates.isEmpty)
          Text('All your devices are in $workspaceName already.')
        else
          ResponsiveList.plain(
            rows: <ListRowData>[
              for (final Device device in candidates)
                ListRowData(
                  key: ValueKey<DeviceId>(device.id),
                  main: ListRowMain.monospace(
                    title: device.name,
                    subtitle: <TextSegment>[TextSegment(device.role.label)],
                  ),
                  end: AppButton.secondary(
                    label: 'Add',
                    onPressed: () => navigator.pop(device.id),
                  ),
                ),
            ],
          ),
      ],
      actions: <Widget>[
        AppButton.secondary(label: 'Close', onPressed: navigator.pop),
      ],
    );
  }
}
