import Cocoa
import FlutterMacOS

private let engineName = "agon"

@main
class AppDelegate: FlutterAppDelegate {
  private let engine = FlutterEngine(name: engineName, project: nil)
  private var runnerPresence: RunnerPresenceChannel?
  private var windowChannel: WindowChannel?

  override func applicationDidFinishLaunching(_ notification: Notification) {
    let windows = WindowChannel(messenger: engine.binaryMessenger)
    windowChannel = windows
    runnerPresence = RunnerPresenceChannel(
      messenger: engine.binaryMessenger,
      menuBarItem: MenuBarItem(onOpen: windows.reopen),
      loginItem: LoginItem()
    )
    engine.run(withEntrypoint: nil)
    RegisterGeneratedPlugins(registry: engine)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(
    _ sender: NSApplication
  ) -> Bool {
    let keepsRunning = runnerPresence?.keepsAppRunning ?? false
    return !keepsRunning
  }

  override func applicationShouldHandleReopen(
    _ sender: NSApplication,
    hasVisibleWindows: Bool
  ) -> Bool {
    if !hasVisibleWindows {
      windowChannel?.reopen()
    }
    return true
  }

  override func applicationSupportsSecureRestorableState(
    _ app: NSApplication
  ) -> Bool {
    return true
  }

  @IBAction func openNewWindow(_ sender: Any?) {
    windowChannel?.openNewWindow()
  }
}
