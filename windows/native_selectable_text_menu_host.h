#ifndef FLUTTER_PLUGIN_NATIVE_SELECTABLE_TEXT_MENU_HOST_H_
#define FLUTTER_PLUGIN_NATIVE_SELECTABLE_TEXT_MENU_HOST_H_

// This must be included before many other Windows headers.
#include <windows.h>

#include <flutter/binary_messenger.h>

#include <cstdint>
#include <functional>
#include <memory>
#include <optional>
#include <string>
#include <vector>

#include "native_selectable_text.g.h"

namespace oh_my_flutter {

// Owns a single native Windows selection menu for one Flutter engine.
class NativeSelectableTextMenuHost : public NativeSelectableTextMenuHostApi {
public:
  NativeSelectableTextMenuHost(
      HWND view_window, HWND owner_window, UINT presentation_message,
      std::function<void(int64_t, int64_t, std::function<void()>)> on_action,
      std::function<void(int64_t, bool)> on_dismissed);
  ~NativeSelectableTextMenuHost() override;

  NativeSelectableTextMenuHost(const NativeSelectableTextMenuHost &) = delete;
  NativeSelectableTextMenuHost &
  operator=(const NativeSelectableTextMenuHost &) = delete;

  ErrorOr<bool>
  Show(const NativeSelectableTextMenuRequestMessage &request) override;
  ErrorOr<bool>
  Update(const NativeSelectableTextMenuRequestMessage &request) override;
  ErrorOr<bool>
  UpdateGeometry(int64_t session_identifier,
                 const std::vector<double> &geometry) override;
  std::optional<FlutterError> Hide(int64_t session_identifier) override;

  // Presents a queued menu when the plugin receives its private window
  // message. Returns true only for that message.
  bool HandleWindowMessage(UINT message);

protected:
  virtual bool HasNativeHost() const;
  virtual bool SchedulePresentation();
  virtual void DismissActiveMenu();
  virtual UINT PresentNativeMenu(HMENU menu, const POINT &anchor,
                                 const RECT &exclusion_rectangle);
  virtual double DevicePixelRatio() const;
  virtual bool ConvertViewPointToScreen(POINT *point) const;

  // Runs a queued presentation. Exposed to platform tests through a subclass.
  void PresentPendingMenu();

private:
  bool
  ReplacePendingMenu(const NativeSelectableTextMenuRequestMessage &request);
  void
  ReplacePendingRequest(const NativeSelectableTextMenuRequestMessage &request);
  void
  UpdatePendingGeometry(const NativeSelectableTextMenuRequestMessage &request);
  void UpdatePendingGeometry(const std::vector<double> &geometry);
  bool QueuePendingPresentation();
  bool IsCurrentSession(int64_t session_identifier) const;
  bool
  IsValidRequest(const NativeSelectableTextMenuRequestMessage &request) const;
  static bool IsValidGeometry(const std::vector<double> &geometry);
  static bool GeometryMatches(
      const NativeSelectableTextMenuRequestMessage &request,
      const std::vector<double> &geometry);
  bool
  RequestsEqual(const NativeSelectableTextMenuRequestMessage &first,
                const NativeSelectableTextMenuRequestMessage &second) const;
  bool
  MenuItemsEqual(const NativeSelectableTextMenuRequestMessage &first,
                 const NativeSelectableTextMenuRequestMessage &second) const;
  HMENU BuildMenu(const NativeSelectableTextMenuRequestMessage &request,
                  std::vector<int64_t> *action_identifiers) const;
  POINT ScreenPoint(const NativeSelectableTextPointMessage &point) const;
  RECT
  ScreenRectangle(const NativeSelectableTextRectangleMessage &rectangle) const;
  static std::wstring Utf8ToWide(const std::string &value);
  static bool HasVisibleLabel(const std::wstring &value);
  static std::wstring EscapeMenuLabel(const std::wstring &value);
  void ClearAllMenusSilently();
  void ClearSessionSilently(int64_t session_identifier);
  void DestroyPendingMenu();
  void SendAction(int64_t session_identifier, int64_t action_identifier,
                  std::function<void()> on_completed);
  void SendDismissed(int64_t session_identifier, bool action_invoked);

  HWND view_window_;
  HWND owner_window_;
  UINT presentation_message_;
  std::function<void(int64_t, int64_t, std::function<void()>)> on_action_;
  std::function<void(int64_t, bool)> on_dismissed_;
  std::shared_ptr<bool> lifecycle_token_ = std::make_shared<bool>(true);

  std::optional<NativeSelectableTextMenuRequestMessage> pending_request_;
  HMENU pending_menu_ = nullptr;
  std::vector<int64_t> pending_action_identifiers_;
  bool presentation_queued_ = false;

  HMENU active_menu_ = nullptr;
  std::optional<NativeSelectableTextMenuRequestMessage> active_request_;
  int64_t active_session_identifier_ = 0;
  bool suppress_active_dismissal_ = false;
  bool reuse_active_menu_for_pending_ = false;
};

} // namespace oh_my_flutter

#endif // FLUTTER_PLUGIN_NATIVE_SELECTABLE_TEXT_MENU_HOST_H_
