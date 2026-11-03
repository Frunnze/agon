part of 'app_route.dart';

sealed class SetupRoute extends AppRoute {
  const SetupRoute() : super(AppSection.devices);
}

final class SetupRoleRoute extends SetupRoute {
  const SetupRoleRoute();
}

final class PairingCodeEntryRoute extends SetupRoute {
  const PairingCodeEntryRoute(this.role);

  final DeviceRole role;

  @override
  String get identity => role.name;
}

final class PairingDoneRoute extends SetupRoute {
  const PairingDoneRoute(this.outcome);

  final PairingOutcome outcome;

  @override
  String get identity => outcome.deviceName;
}
