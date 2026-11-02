import FlutterMacOS

private let channelName = "agent_orchestration/runner_presence"
private let stayInTrayMethod = "stayInTray"
private let leaveTrayMethod = "leaveTray"
private let registerLoginItemMethod = "registerLoginItem"
private let unregisterLoginItemMethod = "unregisterLoginItem"
private let loginItemErrorCode = "login_item"

final class RunnerPresenceChannel {
  private let channel: FlutterMethodChannel
  private let menuBarItem: MenuBarItem
  private let loginItem: LoginItem

  init(
    messenger: FlutterBinaryMessenger,
    menuBarItem: MenuBarItem,
    loginItem: LoginItem
  ) {
    channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: messenger
    )
    self.menuBarItem = menuBarItem
    self.loginItem = loginItem
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  var keepsAppRunning: Bool {
    return menuBarItem.isShown
  }

  private func handle(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    switch call.method {
    case stayInTrayMethod:
      menuBarItem.show()
      result(nil)
    case leaveTrayMethod:
      menuBarItem.hide()
      result(nil)
    case registerLoginItemMethod:
      answer(result) { try loginItem.register() }
    case unregisterLoginItemMethod:
      answer(result) { try loginItem.unregister() }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func answer(
    _ result: FlutterResult,
    by loginItemChange: () throws -> Void
  ) {
    do {
      try loginItemChange()
      result(nil)
    } catch let failure {
      let error = FlutterError(
        code: loginItemErrorCode,
        message: failure.localizedDescription,
        details: nil
      )
      result(error)
    }
  }
}
