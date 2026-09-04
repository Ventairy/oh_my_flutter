#include "include/oh_my_flutter/oh_my_flutter_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

#include "native_selectable_text.g.h"
#include "native_selectable_text_menu_host.h"

void oh_my_flutter_plugin_register_with_registrar(
    FlPluginRegistrar *registrar) {
  FlBinaryMessenger *messenger = fl_plugin_registrar_get_messenger(registrar);
  FlView *flutter_view = fl_plugin_registrar_get_view(registrar);
  auto *menu_host = new oh_my_flutter::NativeSelectableTextMenuHost(
      messenger, flutter_view == nullptr ? nullptr : GTK_WIDGET(flutter_view));

  static const OhMyFlutterNativeSelectableTextMenuHostApiVTable vtable = {
      oh_my_flutter::NativeSelectableTextMenuHost::Show,
      oh_my_flutter::NativeSelectableTextMenuHost::Update,
      oh_my_flutter::NativeSelectableTextMenuHost::UpdateGeometry,
      oh_my_flutter::NativeSelectableTextMenuHost::Hide,
  };
  oh_my_flutter_native_selectable_text_menu_host_api_set_method_handlers(
      messenger, nullptr, &vtable, menu_host, [](gpointer user_data) {
        delete static_cast<oh_my_flutter::NativeSelectableTextMenuHost *>(
            user_data);
      });
}
