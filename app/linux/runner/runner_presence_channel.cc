#include "runner_presence_channel.h"

static const char kChannelName[] = "agent_orchestration/runner_presence";
static const char kStayInTrayMethod[] = "stayInTray";
static const char kLeaveTrayMethod[] = "leaveTray";
static const char kTrayErrorCode[] = "tray";

static FlMethodResponse* answer_stay_in_tray(TrayIcon* tray_icon) {
  g_autoptr(GError) error = nullptr;
  if (!tray_icon_show(tray_icon, &error)) {
    return FL_METHOD_RESPONSE(
        fl_method_error_response_new(kTrayErrorCode, error->message, nullptr));
  }
  return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
}

static FlMethodResponse* answer_leave_tray(TrayIcon* tray_icon) {
  tray_icon_hide(tray_icon);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
}

static FlMethodResponse* answer_method_call(const gchar* method,
                                            TrayIcon* tray_icon) {
  if (g_strcmp0(method, kStayInTrayMethod) == 0) {
    return answer_stay_in_tray(tray_icon);
  }
  if (g_strcmp0(method, kLeaveTrayMethod) == 0) {
    return answer_leave_tray(tray_icon);
  }
  return FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
}

static void method_call_cb(FlMethodChannel* channel,
                           FlMethodCall* method_call,
                           gpointer user_data) {
  TrayIcon* tray_icon = static_cast<TrayIcon*>(user_data);
  const gchar* method = fl_method_call_get_name(method_call);
  g_autoptr(FlMethodResponse) response =
      answer_method_call(method, tray_icon);

  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond(method_call, response, &error)) {
    g_warning("could not answer %s: %s", method, error->message);
  }
}

FlMethodChannel* runner_presence_channel_new(FlBinaryMessenger* messenger,
                                             TrayIcon* tray_icon) {
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  FlMethodChannel* channel =
      fl_method_channel_new(messenger, kChannelName, FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb,
                                            tray_icon, nullptr);
  return channel;
}
