import 'package:agent_orchestration/background/login_item.dart';
import 'package:agent_orchestration/background/start_at_login_choice_store.dart';
import 'package:agent_orchestration/background/tray_presence.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/rules/device_roles.dart';

typedef _PresenceChange = Future<void> Function();

final class RunnerPresence {
  RunnerPresence({
    required this.loginItem,
    required this.trayPresence,
    required this.startAtLoginChoiceStore,
  });

  final LoginItem loginItem;
  final TrayPresence trayPresence;
  final StartAtLoginChoiceStore startAtLoginChoiceStore;
  Future<void> _previousChangeDone = Future<void>.value();

  Future<void> keepForRole(DeviceRole role) {
    return _runAfterPreviousChange(() => _keepForRole(role));
  }

  Future<void> startAtLogin() {
    return _runAfterPreviousChange(() async {
      await loginItem.register();
      await startAtLoginChoiceStore.saveIsStartAtLoginChosen(isChosen: true);
    });
  }

  Future<void> stopStartingAtLogin() {
    return _runAfterPreviousChange(() async {
      await loginItem.unregister();
      await startAtLoginChoiceStore.saveIsStartAtLoginChosen(isChosen: false);
    });
  }

  Future<void> remove() {
    return _runAfterPreviousChange(() async {
      await trayPresence.leaveTray();
      await loginItem.unregister();
    });
  }

  Future<void> _keepForRole(DeviceRole role) async {
    if (!roleRunsTasks(role)) {
      return;
    }

    await trayPresence.stayInTray();

    final bool isStartAtLoginChosen = await startAtLoginChoiceStore
        .readIsStartAtLoginChosen();
    if (isStartAtLoginChosen) {
      await loginItem.register();
    }
  }

  Future<void> _runAfterPreviousChange(_PresenceChange change) {
    final Future<void> changeDone = _previousChangeDone.then(
      (void _) => change(),
    );
    _previousChangeDone = changeDone.then((void _) {}, onError: (Object _) {});
    return changeDone;
  }
}
