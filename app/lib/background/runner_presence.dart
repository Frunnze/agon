import 'package:agent_orchestration/background/login_item.dart';
import 'package:agent_orchestration/background/tray_presence.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/rules/device_roles.dart';

final class RunnerPresence {
  const RunnerPresence({required this.loginItem, required this.trayPresence});

  final LoginItem loginItem;
  final TrayPresence trayPresence;

  Future<void> keepForRole(DeviceRole role) async {
    if (!roleRunsTasks(role)) {
      return;
    }

    await trayPresence.stayInTray();
    await loginItem.register();
  }

  Future<void> remove() async {
    await trayPresence.leaveTray();
    await loginItem.unregister();
  }
}
