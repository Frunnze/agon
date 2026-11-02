#ifndef RUNNER_TRAY_ICON_H_
#define RUNNER_TRAY_ICON_H_

#include <gtk/gtk.h>

typedef struct _TrayIcon TrayIcon;

TrayIcon* tray_icon_new(GtkWindow* window, GApplication* application);

gboolean tray_icon_show(TrayIcon* tray_icon, GError** error);

void tray_icon_hide(TrayIcon* tray_icon);

gboolean tray_icon_is_shown(TrayIcon* tray_icon);

void tray_icon_free(TrayIcon* tray_icon);

#endif
