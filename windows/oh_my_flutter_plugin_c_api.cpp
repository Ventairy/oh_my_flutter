#include "include/oh_my_flutter/oh_my_flutter_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "oh_my_flutter_plugin.h"

void OhMyFlutterPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  oh_my_flutter::OhMyFlutterPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
