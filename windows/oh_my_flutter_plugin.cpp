#include "oh_my_flutter_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

#include <flutter/flutter_view.h>

#include <memory>
#include <utility>

namespace oh_my_flutter {

void OhMyFlutterPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  registrar->AddPlugin(std::make_unique<OhMyFlutterPlugin>(registrar));
}

OhMyFlutterPlugin::OhMyFlutterPlugin(flutter::PluginRegistrarWindows *registrar)
    : registrar_(registrar),
      flutter_api_(std::make_shared<NativeSelectableTextMenuFlutterApi>(
          registrar->messenger())) {
  HWND view_window = nullptr;
  HWND owner_window = nullptr;
  if (registrar->GetView() != nullptr) {
    view_window = registrar->GetView()->GetNativeWindow();
    owner_window = GetAncestor(view_window, GA_ROOT);
    if (owner_window == nullptr) {
      owner_window = view_window;
    }
  }

  const UINT presentation_message = RegisterWindowMessageW(
      L"dev.ventairy.oh_my_flutter.NativeSelectableText.present");
  const std::weak_ptr<NativeSelectableTextMenuFlutterApi> weak_flutter_api =
      flutter_api_;
  menu_host_ = std::make_unique<NativeSelectableTextMenuHost>(
      view_window, owner_window, presentation_message,
      [weak_flutter_api](int64_t session_identifier, int64_t action_identifier,
                         std::function<void()> on_completed) {
        const auto flutter_api = weak_flutter_api.lock();
        if (flutter_api == nullptr) {
          return;
        }
        const auto pending_completion =
            std::make_shared<std::function<void()>>(std::move(on_completed));
        const auto complete_once = [pending_completion] {
          if (!*pending_completion) {
            return;
          }
          auto completion = std::move(*pending_completion);
          *pending_completion = nullptr;
          completion();
        };
        flutter_api->OnAction(
            session_identifier, action_identifier, complete_once,
            [complete_once](const FlutterError &) { complete_once(); });
      },
      [weak_flutter_api](int64_t session_identifier, bool action_invoked) {
        const auto flutter_api = weak_flutter_api.lock();
        if (flutter_api == nullptr) {
          return;
        }
        flutter_api->OnDismissed(
            session_identifier, action_invoked, [] {},
            [](const FlutterError &) {});
      });

  NativeSelectableTextMenuHostApi::SetUp(registrar->messenger(),
                                         menu_host_.get());
  window_proc_delegate_identifier_ =
      registrar->RegisterTopLevelWindowProcDelegate(
          [this](HWND, UINT message, WPARAM, LPARAM) -> std::optional<LRESULT> {
            if (menu_host_->HandleWindowMessage(message)) {
              return 0;
            }
            return std::nullopt;
          });
}

OhMyFlutterPlugin::~OhMyFlutterPlugin() {
  NativeSelectableTextMenuHostApi::SetUp(registrar_->messenger(), nullptr);
  if (window_proc_delegate_identifier_ >= 0) {
    registrar_->UnregisterTopLevelWindowProcDelegate(
        window_proc_delegate_identifier_);
  }
  menu_host_.reset();
  flutter_api_.reset();
}

} // namespace oh_my_flutter
