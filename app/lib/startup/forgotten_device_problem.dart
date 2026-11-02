const Set<String> _forgottenDeviceMessages = <String>{
  'the app server answered 401: the device is not paired',
  'the app server answered 403: the device has been revoked',
  'this device has no account yet',
};

bool isForgottenDeviceProblem(Object problem) {
  if (problem is! StateError) {
    return false;
  }
  return _forgottenDeviceMessages.contains(problem.message);
}
