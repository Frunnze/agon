#ifndef RUNNER_RUNNER_PRESENCE_CHANNEL_H_
#define RUNNER_RUNNER_PRESENCE_CHANNEL_H_

#include <flutter_linux/flutter_linux.h>

#include "tray_icon.h"

FlMethodChannel* runner_presence_channel_new(FlBinaryMessenger* messenger,
                                             TrayIcon* tray_icon);

#endif
