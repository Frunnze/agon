import Cocoa
import FlutterMacOS

private let channelName = "agent_orchestration/folders"
private let chooseFolderMethod = "chooseFolder"
private let chooseButtonTitle = "Choose"

final class FolderChannel {
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

  private func handle(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    guard call.method == chooseFolderMethod else {
      result(FlutterMethodNotImplemented)
      return
    }
    chooseFolder(result: result)
  }

  private func chooseFolder(result: @escaping FlutterResult) {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    panel.canCreateDirectories = true
    panel.prompt = chooseButtonTitle
    panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser

    let answer: (NSApplication.ModalResponse) -> Void = { response in
      let isChosen = response == .OK
      result(isChosen ? panel.url?.path : nil)
    }
    guard let window = NSApp.keyWindow ?? NSApp.mainWindow else {
      answer(panel.runModal())
      return
    }
    panel.beginSheetModal(for: window, completionHandler: answer)
  }
}
