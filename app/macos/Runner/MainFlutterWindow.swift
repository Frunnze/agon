import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var runnerPresence: RunnerPresenceChannel?

  var keepsAppRunningWhenClosed: Bool {
    return runnerPresence?.keepsAppRunning ?? false
  }

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    runnerPresence = RunnerPresenceChannel(
      messenger: flutterViewController.engine.binaryMessenger,
      menuBarItem: MenuBarItem(window: self),
      loginItem: LoginItem()
    )

    super.awakeFromNib()
  }
}
