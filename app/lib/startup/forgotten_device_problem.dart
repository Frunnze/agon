import 'package:agent_orchestration/data/repository/app_server_refusal.dart';
import 'package:agent_orchestration/data/repository/device_without_account.dart';

typedef _ForgottenDeviceRefusal = ({int status, String reason});

const int _unauthorizedStatus = 401;
const int _forbiddenStatus = 403;
const Set<_ForgottenDeviceRefusal> _forgottenDeviceRefusals =
    <_ForgottenDeviceRefusal>{
      (status: _unauthorizedStatus, reason: 'the device is not paired'),
      (status: _forbiddenStatus, reason: 'the device has been revoked'),
    };

bool isForgottenDeviceProblem(Object problem) {
  if (problem is DeviceWithoutAccount) {
    return true;
  }
  if (problem is! AppServerRefusal) {
    return false;
  }

  final _ForgottenDeviceRefusal answer = (
    status: problem.status,
    reason: problem.message,
  );
  return _forgottenDeviceRefusals.contains(answer);
}
