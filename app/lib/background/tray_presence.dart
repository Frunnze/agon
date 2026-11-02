abstract interface class TrayPresence {
  Future<void> stayInTray();

  Future<void> leaveTray();
}
