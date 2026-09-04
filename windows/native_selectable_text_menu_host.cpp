#include "native_selectable_text_menu_host.h"

#include <flutter/encodable_value.h>

#include <algorithm>
#include <any>
#include <cmath>
#include <limits>
#include <string>
#include <utility>

namespace oh_my_flutter {

namespace {

constexpr size_t kGeometryValueCount = 6;
constexpr size_t kGeometryLeftIndex = 0;
constexpr size_t kGeometryTopIndex = 1;
constexpr size_t kGeometryRightIndex = 2;
constexpr size_t kGeometryBottomIndex = 3;
constexpr size_t kGeometryAnchorDxIndex = 4;
constexpr size_t kGeometryAnchorDyIndex = 5;

} // namespace

NativeSelectableTextMenuHost::NativeSelectableTextMenuHost(
    HWND view_window, HWND owner_window, UINT presentation_message,
    std::function<void(int64_t, int64_t, std::function<void()>)> on_action,
    std::function<void(int64_t, bool)> on_dismissed)
    : view_window_(view_window), owner_window_(owner_window),
      presentation_message_(presentation_message),
      on_action_(std::move(on_action)), on_dismissed_(std::move(on_dismissed)) {
}

NativeSelectableTextMenuHost::~NativeSelectableTextMenuHost() {
  lifecycle_token_.reset();
  suppress_active_dismissal_ = true;
  if (active_menu_ != nullptr) {
    DismissActiveMenu();
  }
  active_request_.reset();
  reuse_active_menu_for_pending_ = false;
  DestroyPendingMenu();
}

ErrorOr<bool> NativeSelectableTextMenuHost::Show(
    const NativeSelectableTextMenuRequestMessage &request) {
  if (!HasNativeHost() || !IsValidRequest(request)) {
    ClearAllMenusSilently();
    return false;
  }

  if (!ReplacePendingMenu(request)) {
    ClearAllMenusSilently();
    return false;
  }

  if (active_menu_ != nullptr) {
    if (!QueuePendingPresentation()) {
      ClearAllMenusSilently();
      return false;
    }
    suppress_active_dismissal_ = true;
    DismissActiveMenu();
    return true;
  }

  if (!QueuePendingPresentation()) {
    DestroyPendingMenu();
    return false;
  }

  return true;
}

ErrorOr<bool> NativeSelectableTextMenuHost::Update(
    const NativeSelectableTextMenuRequestMessage &request) {
  const int64_t session_identifier = request.session_identifier();
  if (!IsCurrentSession(session_identifier)) {
    return false;
  }
  if (!HasNativeHost() || !IsValidRequest(request)) {
    ClearSessionSilently(session_identifier);
    return false;
  }

  if (pending_request_.has_value()) {
    if (RequestsEqual(*pending_request_, request)) {
      return true;
    }
    if (MenuItemsEqual(*pending_request_, request)) {
      UpdatePendingGeometry(request);
      return true;
    }
  } else if (active_request_.has_value()) {
    if (RequestsEqual(*active_request_, request)) {
      return true;
    }
    if (MenuItemsEqual(*active_request_, request)) {
      if (!QueuePendingPresentation()) {
        ClearSessionSilently(session_identifier);
        return false;
      }
      ReplacePendingRequest(request);
      reuse_active_menu_for_pending_ = true;
      suppress_active_dismissal_ = true;
      DismissActiveMenu();
      return true;
    }
  }

  if (!ReplacePendingMenu(request)) {
    ClearSessionSilently(session_identifier);
    return false;
  }

  if (active_menu_ != nullptr) {
    if (!QueuePendingPresentation()) {
      ClearSessionSilently(session_identifier);
      return false;
    }
    suppress_active_dismissal_ = true;
    DismissActiveMenu();
    return true;
  }

  if (!QueuePendingPresentation()) {
    DestroyPendingMenu();
    return false;
  }

  return true;
}

ErrorOr<bool> NativeSelectableTextMenuHost::UpdateGeometry(
    int64_t session_identifier, const std::vector<double> &geometry) {
  if (!IsCurrentSession(session_identifier)) {
    return false;
  }
  if (!HasNativeHost() || !IsValidGeometry(geometry)) {
    ClearSessionSilently(session_identifier);
    return false;
  }

  if (pending_request_.has_value()) {
    if (pending_request_->session_identifier() != session_identifier) {
      return false;
    }
    if (!GeometryMatches(*pending_request_, geometry)) {
      UpdatePendingGeometry(geometry);
    }
    return true;
  }
  if (!active_request_.has_value() ||
      active_session_identifier_ != session_identifier) {
    return false;
  }
  if (GeometryMatches(*active_request_, geometry)) {
    return true;
  }
  if (!QueuePendingPresentation()) {
    ClearSessionSilently(session_identifier);
    return false;
  }

  pending_request_.emplace(std::move(*active_request_));
  active_request_.reset();
  UpdatePendingGeometry(geometry);
  reuse_active_menu_for_pending_ = true;
  suppress_active_dismissal_ = true;
  DismissActiveMenu();
  return true;
}

std::optional<FlutterError>
NativeSelectableTextMenuHost::Hide(int64_t session_identifier) {
  if (pending_request_.has_value() &&
      pending_request_->session_identifier() == session_identifier) {
    DestroyPendingMenu();
  }

  if (active_menu_ != nullptr &&
      active_session_identifier_ == session_identifier) {
    suppress_active_dismissal_ = true;
    DismissActiveMenu();
  }

  return std::nullopt;
}

bool NativeSelectableTextMenuHost::HandleWindowMessage(UINT message) {
  if (message != presentation_message_) {
    return false;
  }

  presentation_queued_ = false;
  PresentPendingMenu();
  return true;
}

bool NativeSelectableTextMenuHost::HasNativeHost() const {
  return view_window_ != nullptr && owner_window_ != nullptr &&
         presentation_message_ != 0 && IsWindow(view_window_) != FALSE &&
         IsWindow(owner_window_) != FALSE;
}

bool NativeSelectableTextMenuHost::SchedulePresentation() {
  return PostMessage(owner_window_, presentation_message_, 0, 0) != FALSE;
}

void NativeSelectableTextMenuHost::DismissActiveMenu() { EndMenu(); }

UINT NativeSelectableTextMenuHost::PresentNativeMenu(
    HMENU menu, const POINT &anchor, const RECT &exclusion_rectangle) {
  TPMPARAMS parameters = {};
  parameters.cbSize = sizeof(parameters);
  parameters.rcExclude = exclusion_rectangle;

  return TrackPopupMenuEx(menu, TPM_RETURNCMD | TPM_NONOTIFY | TPM_RIGHTBUTTON,
                          anchor.x, anchor.y, owner_window_, &parameters);
}

double NativeSelectableTextMenuHost::DevicePixelRatio() const {
  if (view_window_ == nullptr) {
    return 1.0;
  }

  const UINT dpi = GetDpiForWindow(view_window_);
  return dpi == 0 ? 1.0 : static_cast<double>(dpi) / 96.0;
}

bool NativeSelectableTextMenuHost::ConvertViewPointToScreen(
    POINT *point) const {
  return view_window_ != nullptr &&
         ClientToScreen(view_window_, point) != FALSE;
}

void NativeSelectableTextMenuHost::PresentPendingMenu() {
  if (active_menu_ != nullptr || pending_menu_ == nullptr ||
      !pending_request_.has_value()) {
    return;
  }
  if (!HasNativeHost()) {
    const int64_t session_identifier = pending_request_->session_identifier();
    DestroyPendingMenu();
    SendDismissed(session_identifier, false);
    return;
  }

  active_request_.emplace(std::move(*pending_request_));
  HMENU menu = pending_menu_;
  std::vector<int64_t> action_identifiers =
      std::move(pending_action_identifiers_);
  pending_request_.reset();
  pending_menu_ = nullptr;

  active_menu_ = menu;
  active_session_identifier_ = active_request_->session_identifier();
  suppress_active_dismissal_ = false;

  const POINT anchor = ScreenPoint(active_request_->primary_anchor());
  const RECT exclusion_rectangle =
      ScreenRectangle(active_request_->selection_rectangle());
  const int64_t session_identifier = active_session_identifier_;
  const UINT command = PresentNativeMenu(menu, anchor, exclusion_rectangle);

  const bool should_report =
      active_menu_ == menu && !suppress_active_dismissal_;
  active_menu_ = nullptr;
  active_session_identifier_ = 0;
  active_request_.reset();
  const bool should_reuse_menu =
      reuse_active_menu_for_pending_ && pending_request_.has_value() &&
      !should_report;
  reuse_active_menu_for_pending_ = false;
  if (should_reuse_menu) {
    pending_menu_ = menu;
    pending_action_identifiers_ = std::move(action_identifiers);
  } else {
    DestroyMenu(menu);
  }

  if (should_report) {
    const bool action_invoked =
        command > 0 && command <= action_identifiers.size();
    if (action_invoked) {
      const auto on_dismissed = on_dismissed_;
      SendAction(session_identifier, action_identifiers[command - 1],
                 [on_dismissed, session_identifier] {
                   if (on_dismissed) {
                     on_dismissed(session_identifier, true);
                   }
                 });
    } else {
      SendDismissed(session_identifier, false);
    }
  }

  if (pending_menu_ != nullptr && !presentation_queued_ &&
      !QueuePendingPresentation()) {
    DestroyPendingMenu();
  }
}

bool NativeSelectableTextMenuHost::ReplacePendingMenu(
    const NativeSelectableTextMenuRequestMessage &request) {
  std::vector<int64_t> action_identifiers;
  HMENU menu = BuildMenu(request, &action_identifiers);
  if (menu == nullptr) {
    return false;
  }

  DestroyPendingMenu();
  pending_request_ = request;
  pending_menu_ = menu;
  pending_action_identifiers_ = std::move(action_identifiers);
  return true;
}

void NativeSelectableTextMenuHost::ReplacePendingRequest(
    const NativeSelectableTextMenuRequestMessage &request) {
  pending_request_ = request;
}

void NativeSelectableTextMenuHost::UpdatePendingGeometry(
    const NativeSelectableTextMenuRequestMessage &request) {
  pending_request_->set_selection_rectangle(request.selection_rectangle());
  pending_request_->set_primary_anchor(request.primary_anchor());
}

void NativeSelectableTextMenuHost::UpdatePendingGeometry(
    const std::vector<double> &geometry) {
  pending_request_->set_selection_rectangle(NativeSelectableTextRectangleMessage(
      geometry[kGeometryLeftIndex], geometry[kGeometryTopIndex],
      geometry[kGeometryRightIndex], geometry[kGeometryBottomIndex]));
  pending_request_->set_primary_anchor(NativeSelectableTextPointMessage(
      geometry[kGeometryAnchorDxIndex], geometry[kGeometryAnchorDyIndex]));
}

bool NativeSelectableTextMenuHost::QueuePendingPresentation() {
  if (presentation_queued_) {
    return true;
  }

  presentation_queued_ = SchedulePresentation();
  return presentation_queued_;
}

bool NativeSelectableTextMenuHost::IsCurrentSession(
    int64_t session_identifier) const {
  if (pending_request_.has_value() &&
      pending_request_->session_identifier() == session_identifier) {
    return true;
  }

  return active_menu_ != nullptr &&
         active_session_identifier_ == session_identifier;
}

bool NativeSelectableTextMenuHost::IsValidRequest(
    const NativeSelectableTextMenuRequestMessage &request) const {
  const auto &rectangle = request.selection_rectangle();
  const auto &anchor = request.primary_anchor();
  return !request.items().empty() && std::isfinite(rectangle.left()) &&
         std::isfinite(rectangle.top()) && std::isfinite(rectangle.right()) &&
         std::isfinite(rectangle.bottom()) &&
         rectangle.right() >= rectangle.left() &&
         rectangle.bottom() >= rectangle.top() && std::isfinite(anchor.dx()) &&
         std::isfinite(anchor.dy());
}

bool NativeSelectableTextMenuHost::IsValidGeometry(
    const std::vector<double> &geometry) {
  return geometry.size() == kGeometryValueCount &&
         std::isfinite(geometry[kGeometryLeftIndex]) &&
         std::isfinite(geometry[kGeometryTopIndex]) &&
         std::isfinite(geometry[kGeometryRightIndex]) &&
         std::isfinite(geometry[kGeometryBottomIndex]) &&
         geometry[kGeometryRightIndex] >= geometry[kGeometryLeftIndex] &&
         geometry[kGeometryBottomIndex] >= geometry[kGeometryTopIndex] &&
         std::isfinite(geometry[kGeometryAnchorDxIndex]) &&
         std::isfinite(geometry[kGeometryAnchorDyIndex]);
}

bool NativeSelectableTextMenuHost::GeometryMatches(
    const NativeSelectableTextMenuRequestMessage &request,
    const std::vector<double> &geometry) {
  if (geometry.size() != kGeometryValueCount) {
    return false;
  }
  const NativeSelectableTextRectangleMessage &rectangle =
      request.selection_rectangle();
  const NativeSelectableTextPointMessage &anchor = request.primary_anchor();
  return rectangle.left() == geometry[kGeometryLeftIndex] &&
         rectangle.top() == geometry[kGeometryTopIndex] &&
         rectangle.right() == geometry[kGeometryRightIndex] &&
         rectangle.bottom() == geometry[kGeometryBottomIndex] &&
         anchor.dx() == geometry[kGeometryAnchorDxIndex] &&
         anchor.dy() == geometry[kGeometryAnchorDyIndex];
}

bool NativeSelectableTextMenuHost::RequestsEqual(
    const NativeSelectableTextMenuRequestMessage &first,
    const NativeSelectableTextMenuRequestMessage &second) const {
  return first.session_identifier() == second.session_identifier() &&
         first.selection_rectangle() == second.selection_rectangle() &&
         first.primary_anchor() == second.primary_anchor() &&
         MenuItemsEqual(first, second);
}

bool NativeSelectableTextMenuHost::MenuItemsEqual(
    const NativeSelectableTextMenuRequestMessage &first,
    const NativeSelectableTextMenuRequestMessage &second) const {
  if (first.items().size() != second.items().size()) {
    return false;
  }

  for (size_t index = 0; index < first.items().size(); ++index) {
    const auto *first_custom =
        std::get_if<flutter::CustomEncodableValue>(&first.items()[index]);
    const auto *second_custom =
        std::get_if<flutter::CustomEncodableValue>(&second.items()[index]);
    if (first_custom == nullptr || second_custom == nullptr ||
        first_custom->type() !=
            typeid(NativeSelectableTextMenuItemMessage) ||
        second_custom->type() !=
            typeid(NativeSelectableTextMenuItemMessage)) {
      return false;
    }

    const auto &first_item =
        std::any_cast<const NativeSelectableTextMenuItemMessage &>(
            *first_custom);
    const auto &second_item =
        std::any_cast<const NativeSelectableTextMenuItemMessage &>(
            *second_custom);
    if (first_item != second_item) {
      return false;
    }
  }

  return true;
}

HMENU NativeSelectableTextMenuHost::BuildMenu(
    const NativeSelectableTextMenuRequestMessage &request,
    std::vector<int64_t> *action_identifiers) const {
  if (request.items().empty() ||
      request.items().size() > std::numeric_limits<UINT>::max()) {
    return nullptr;
  }

  HMENU menu = CreatePopupMenu();
  if (menu == nullptr) {
    return nullptr;
  }

  action_identifiers->reserve(request.items().size());
  for (size_t index = 0; index < request.items().size(); ++index) {
    const auto *custom_value =
        std::get_if<flutter::CustomEncodableValue>(&request.items()[index]);
    if (custom_value == nullptr ||
        custom_value->type() != typeid(NativeSelectableTextMenuItemMessage)) {
      DestroyMenu(menu);
      action_identifiers->clear();
      return nullptr;
    }

    const auto &item =
        std::any_cast<const NativeSelectableTextMenuItemMessage &>(
            *custom_value);
    const std::wstring plain_label = Utf8ToWide(item.label());
    if (!HasVisibleLabel(plain_label)) {
      DestroyMenu(menu);
      action_identifiers->clear();
      return nullptr;
    }
    const std::wstring label = EscapeMenuLabel(plain_label);
    if (AppendMenuW(menu, MF_STRING, static_cast<UINT_PTR>(index + 1),
                    label.c_str()) == FALSE) {
      DestroyMenu(menu);
      action_identifiers->clear();
      return nullptr;
    }
    action_identifiers->push_back(item.identifier());
  }

  return menu;
}

POINT NativeSelectableTextMenuHost::ScreenPoint(
    const NativeSelectableTextPointMessage &point) const {
  const double scale = DevicePixelRatio();
  POINT result = {
      static_cast<LONG>(std::lround(point.dx() * scale)),
      static_cast<LONG>(std::lround(point.dy() * scale)),
  };
  ConvertViewPointToScreen(&result);
  return result;
}

RECT NativeSelectableTextMenuHost::ScreenRectangle(
    const NativeSelectableTextRectangleMessage &rectangle) const {
  const double scale = DevicePixelRatio();
  POINT upper_left = {
      static_cast<LONG>(std::lround(rectangle.left() * scale)),
      static_cast<LONG>(std::lround(rectangle.top() * scale)),
  };
  POINT lower_right = {
      static_cast<LONG>(std::lround(rectangle.right() * scale)),
      static_cast<LONG>(std::lround(rectangle.bottom() * scale)),
  };
  ConvertViewPointToScreen(&upper_left);
  ConvertViewPointToScreen(&lower_right);

  return {
      std::min(upper_left.x, lower_right.x),
      std::min(upper_left.y, lower_right.y),
      std::max(upper_left.x, lower_right.x),
      std::max(upper_left.y, lower_right.y),
  };
}

std::wstring
NativeSelectableTextMenuHost::Utf8ToWide(const std::string &value) {
  if (value.empty() ||
      value.size() > static_cast<size_t>(std::numeric_limits<int>::max())) {
    return {};
  }

  const int output_length =
      MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.data(),
                          static_cast<int>(value.size()), nullptr, 0);
  if (output_length <= 0) {
    return {};
  }

  std::wstring result(output_length, L'\0');
  MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.data(),
                      static_cast<int>(value.size()), result.data(),
                      output_length);
  return result;
}

bool NativeSelectableTextMenuHost::HasVisibleLabel(const std::wstring &value) {
  if (value.empty()) {
    return false;
  }

  for (const wchar_t character : value) {
    WORD character_type = 0;
    if (GetStringTypeW(CT_CTYPE1, &character, 1, &character_type) == FALSE ||
        (character_type & C1_SPACE) == 0) {
      return true;
    }
  }
  return false;
}

std::wstring
NativeSelectableTextMenuHost::EscapeMenuLabel(const std::wstring &value) {
  std::wstring result;
  result.reserve(value.size());
  for (const wchar_t character : value) {
    result.push_back(character);
    if (character == L'&') {
      result.push_back(L'&');
    }
  }
  return result;
}

void NativeSelectableTextMenuHost::ClearAllMenusSilently() {
  DestroyPendingMenu();
  if (active_menu_ == nullptr) {
    return;
  }
  suppress_active_dismissal_ = true;
  DismissActiveMenu();
}

void NativeSelectableTextMenuHost::ClearSessionSilently(
    int64_t session_identifier) {
  if (pending_request_.has_value() &&
      pending_request_->session_identifier() == session_identifier) {
    DestroyPendingMenu();
  }
  if (active_menu_ == nullptr ||
      active_session_identifier_ != session_identifier) {
    return;
  }
  suppress_active_dismissal_ = true;
  DismissActiveMenu();
}

void NativeSelectableTextMenuHost::DestroyPendingMenu() {
  pending_request_.reset();
  pending_action_identifiers_.clear();
  reuse_active_menu_for_pending_ = false;
  if (pending_menu_ != nullptr) {
    DestroyMenu(pending_menu_);
    pending_menu_ = nullptr;
  }
}

void NativeSelectableTextMenuHost::SendAction(
    int64_t session_identifier, int64_t action_identifier,
    std::function<void()> on_completed) {
  if (on_action_) {
    const std::weak_ptr<bool> lifecycle_token = lifecycle_token_;
    on_action_(session_identifier, action_identifier,
               [lifecycle_token, on_completed = std::move(on_completed)] {
                 if (!lifecycle_token.expired() && on_completed) {
                   on_completed();
                 }
               });
    return;
  }
  if (on_completed) {
    on_completed();
  }
}

void NativeSelectableTextMenuHost::SendDismissed(int64_t session_identifier,
                                                 bool action_invoked) {
  if (on_dismissed_) {
    on_dismissed_(session_identifier, action_invoked);
  }
}

} // namespace oh_my_flutter
