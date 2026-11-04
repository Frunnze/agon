import Cocoa

private let openWindowTitle = "Open Agon"
private let quitTitle = "Quit"
private let quitKeyEquivalent = "q"
private let noKeyEquivalent = ""
private let iconSide: CGFloat = 18

final class MenuBarItem: NSObject {
  private let onOpen: () -> Void
  private var statusItem: NSStatusItem?

  init(onOpen: @escaping () -> Void) {
    self.onOpen = onOpen
  }

  var isShown: Bool {
    return statusItem != nil
  }

  func show() {
    if statusItem != nil {
      return
    }

    let item = NSStatusBar.system.statusItem(
      withLength: NSStatusItem.squareLength
    )
    item.button?.image = makeIcon()
    item.menu = makeMenu()
    statusItem = item
  }

  func hide() {
    guard let item = statusItem else {
      return
    }

    NSStatusBar.system.removeStatusItem(item)
    statusItem = nil
  }

  private func makeIcon() -> NSImage? {
    let icon = NSApp.applicationIconImage.copy() as? NSImage
    icon?.size = NSSize(width: iconSide, height: iconSide)
    return icon
  }

  private func makeMenu() -> NSMenu {
    let menu = NSMenu()
    let openItem = makeMenuItem(
      title: openWindowTitle,
      action: #selector(openWindow),
      keyEquivalent: noKeyEquivalent
    )
    let quitItem = makeMenuItem(
      title: quitTitle,
      action: #selector(quit),
      keyEquivalent: quitKeyEquivalent
    )
    menu.addItem(openItem)
    menu.addItem(quitItem)
    return menu
  }

  private func makeMenuItem(
    title: String,
    action: Selector,
    keyEquivalent: String
  ) -> NSMenuItem {
    let item = NSMenuItem(
      title: title,
      action: action,
      keyEquivalent: keyEquivalent
    )
    item.target = self
    return item
  }

  @objc private func openWindow() {
    onOpen()
  }

  @objc private func quit() {
    NSApp.terminate(nil)
  }
}
