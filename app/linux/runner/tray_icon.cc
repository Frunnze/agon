#include "tray_icon.h"

#include <libayatana-appindicator/app-indicator.h>

static const char kExecutableLink[] = "/proc/self/exe";
static const char kIconFolderName[] = "data";
static const char kIconName[] = "app_icon";
static const char kTitle[] = "Agon";
static const char kOpenWindowLabel[] = "Open Agon";
static const char kQuitLabel[] = "Quit";
static const char kActivateSignal[] = "activate";

struct _TrayIcon {
  GtkWindow* window;
  GApplication* application;
  AppIndicator* indicator;
};

static void open_window_cb(GtkMenuItem* menu_item, TrayIcon* tray_icon) {
  gtk_window_present(tray_icon->window);
}

static void quit_cb(GtkMenuItem* menu_item, TrayIcon* tray_icon) {
  g_application_quit(tray_icon->application);
}

static void append_menu_item(GtkWidget* menu,
                             const char* label,
                             GCallback callback,
                             TrayIcon* tray_icon) {
  GtkWidget* menu_item = gtk_menu_item_new_with_label(label);
  g_signal_connect(menu_item, kActivateSignal, callback, tray_icon);
  gtk_menu_shell_append(GTK_MENU_SHELL(menu), menu_item);
}

static GtkMenu* build_menu(TrayIcon* tray_icon) {
  GtkWidget* menu = gtk_menu_new();
  append_menu_item(menu, kOpenWindowLabel, G_CALLBACK(open_window_cb),
                   tray_icon);
  append_menu_item(menu, kQuitLabel, G_CALLBACK(quit_cb), tray_icon);

  gtk_widget_show_all(menu);
  return GTK_MENU(menu);
}

static gchar* find_icon_folder(GError** error) {
  g_autofree gchar* executable = g_file_read_link(kExecutableLink, error);
  if (executable == nullptr) {
    return nullptr;
  }

  g_autofree gchar* bundle_folder = g_path_get_dirname(executable);
  return g_build_filename(bundle_folder, kIconFolderName, nullptr);
}

TrayIcon* tray_icon_new(GtkWindow* window, GApplication* application) {
  TrayIcon* tray_icon = g_new0(TrayIcon, 1);
  tray_icon->window = window;
  tray_icon->application = application;
  return tray_icon;
}

gboolean tray_icon_show(TrayIcon* tray_icon, GError** error) {
  if (tray_icon->indicator != nullptr) {
    return TRUE;
  }

  g_autofree gchar* icon_folder = find_icon_folder(error);
  if (icon_folder == nullptr) {
    return FALSE;
  }

  AppIndicator* indicator = app_indicator_new_with_path(
      APPLICATION_ID, kIconName, APP_INDICATOR_CATEGORY_APPLICATION_STATUS,
      icon_folder);
  app_indicator_set_title(indicator, kTitle);
  app_indicator_set_menu(indicator, build_menu(tray_icon));
  app_indicator_set_status(indicator, APP_INDICATOR_STATUS_ACTIVE);
  tray_icon->indicator = indicator;
  return TRUE;
}

void tray_icon_hide(TrayIcon* tray_icon) {
  g_clear_object(&tray_icon->indicator);
}

gboolean tray_icon_is_shown(TrayIcon* tray_icon) {
  return tray_icon->indicator != nullptr;
}

void tray_icon_free(TrayIcon* tray_icon) {
  tray_icon_hide(tray_icon);
  g_free(tray_icon);
}
