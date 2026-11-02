import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/rules/device_roles.dart';

void main() {
  test('test_role_runs_tasks_property_only_the_client_role_runs_none', () {
    for (final DeviceRole role in DeviceRole.values) {
      expect(roleRunsTasks(role), role != DeviceRole.client);
    }
    expect(roleRunsTasks(DeviceRole.runner), isTrue);
    expect(roleRunsTasks(DeviceRole.clientAndRunner), isTrue);
  });
}
