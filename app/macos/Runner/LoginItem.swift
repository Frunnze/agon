import ServiceManagement

private let registeredStates: Set<SMAppService.Status> = [
  .enabled,
  .requiresApproval,
]
private let unregisteredStates: Set<SMAppService.Status> = [
  .notRegistered,
  .notFound,
]

final class LoginItem {
  private let service = SMAppService.mainApp

  func register() throws {
    if registeredStates.contains(service.status) {
      return
    }
    try service.register()
  }

  func unregister() throws {
    if unregisteredStates.contains(service.status) {
      return
    }
    try service.unregister()
  }
}
