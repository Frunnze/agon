import Cocoa
import FlutterMacOS

private let channelName = "agent_orchestration/windows"
private let openNewWindowMethod = "openNewWindow"
private let reopenMethod = "reopen"
private let keepOnTopMethod = "keepOnTop"
private let stopKeepingOnTopMethod = "stopKeepingOnTop"
private let windowArgument = "window"
private let unknownWindowCode = "unknown_window"
private let unknownWindowMessage = "No open window matches this address"

final class WindowChannel {
  private let channel: FlutterMethodChannel

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  func openNewWindow() {
    channel.invokeMethod(openNewWindowMethod, arguments: nil)
  }

  func reopen() {
    NSApp.activate(ignoringOtherApps: true)
    channel.invokeMethod(reopenMethod, arguments: nil)
  }

  private func handle(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    switch call.method {
    case keepOnTopMethod:
      place(call, at: .floating, result: result)
    case stopKeepingOnTopMethod:
      place(call, at: .normal, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func place(
    _ call: FlutterMethodCall,
    at level: NSWindow.Level,
    result: FlutterResult
  ) {
    guard let window = findWindow(named: call) else {
      let error = FlutterError(
        code: unknownWindowCode,
        message: unknownWindowMessage,
        details: nil
      )
      result(error)
      return
    }

    window.level = level
    result(nil)
  }

  private func findWindow(named call: FlutterMethodCall) -> NSWindow? {
    let arguments = call.arguments as? [String: Any]
    guard let address = arguments?[windowArgument] as? Int else {
      return nil
    }

    return NSApp.windows.first { window in
      let windowAddress = Unmanaged.passUnretained(window).toOpaque()
      return Int(bitPattern: windowAddress) == address
    }
  }
}
