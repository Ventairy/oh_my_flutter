#ifndef FLUTTER_PLUGIN_OH_MY_FLUTTER_PLUGIN_H_
#define FLUTTER_PLUGIN_OH_MY_FLUTTER_PLUGIN_H_

#include <flutter/plugin_registrar_windows.h>

#include <memory>
#include <optional>

#include "native_selectable_text.g.h"
#include "native_selectable_text_menu_host.h"

namespace oh_my_flutter {

class OhMyFlutterPlugin : public flutter::Plugin {
public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  explicit OhMyFlutterPlugin(flutter::PluginRegistrarWindows *registrar);
  ~OhMyFlutterPlugin() override;

  OhMyFlutterPlugin(const OhMyFlutterPlugin &) = delete;
  OhMyFlutterPlugin &operator=(const OhMyFlutterPlugin &) = delete;

private:
  flutter::PluginRegistrarWindows *registrar_;
  int window_proc_delegate_identifier_ = -1;
  std::shared_ptr<NativeSelectableTextMenuFlutterApi> flutter_api_;
  std::unique_ptr<NativeSelectableTextMenuHost> menu_host_;
};

} // namespace oh_my_flutter

#endif // FLUTTER_PLUGIN_OH_MY_FLUTTER_PLUGIN_H_
