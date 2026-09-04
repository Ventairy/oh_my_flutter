#include "native_selectable_text_menu_host.h"

#include <cmath>
#include <mutex>
#include <unordered_map>
#include <utility>

namespace oh_my_flutter {

namespace {

constexpr char kActionIdentifierKey[] =
    "oh-my-flutter-native-selectable-text-action-identifier";
constexpr size_t kGeometryValueCount = 6;
constexpr size_t kGeometryLeftIndex = 0;
constexpr size_t kGeometryTopIndex = 1;
constexpr size_t kGeometryRightIndex = 2;
constexpr size_t kGeometryBottomIndex = 3;
constexpr size_t kGeometryAnchorDxIndex = 4;
constexpr size_t kGeometryAnchorDyIndex = 5;

bool HasVisibleLabel(const gchar *label) {
  if (label == nullptr || !g_utf8_validate(label, -1, nullptr)) {
    return false;
  }
  for (const gchar *character = label; *character != '\0';
       character = g_utf8_next_char(character)) {
    if (!g_unichar_isspace(g_utf8_get_char(character))) {
      return true;
    }
  }
  return false;
}

struct ActionCompletionContext {
  int64_t session_identifier;
  std::weak_ptr<bool> lifecycle_token;
};

// Pigeon callbacks accept unowned gpointer data without a destroy notifier.
// Opaque tokens let host teardown reclaim contexts while late replies stay safe.
struct ActionCompletionRegistry {
  std::mutex mutex;
  std::unordered_map<gsize, ActionCompletionContext> contexts;
  gsize next_identifier = 1;
};

ActionCompletionRegistry &GetActionCompletionRegistry() {
  static ActionCompletionRegistry registry;
  return registry;
}

gpointer RegisterActionCompletion(
    int64_t session_identifier,
    const std::shared_ptr<bool> &lifecycle_token) {
  ActionCompletionRegistry &registry = GetActionCompletionRegistry();
  std::lock_guard<std::mutex> lock(registry.mutex);
  while (registry.next_identifier == 0 ||
         registry.contexts.count(registry.next_identifier) != 0) {
    ++registry.next_identifier;
  }
  const gsize identifier = registry.next_identifier++;
  registry.contexts.emplace(
      identifier,
      ActionCompletionContext{session_identifier, lifecycle_token});
  return GSIZE_TO_POINTER(identifier);
}

bool TakeActionCompletion(gpointer identifier_pointer,
                          ActionCompletionContext *context) {
  const gsize identifier = GPOINTER_TO_SIZE(identifier_pointer);
  ActionCompletionRegistry &registry = GetActionCompletionRegistry();
  std::lock_guard<std::mutex> lock(registry.mutex);
  const auto iterator = registry.contexts.find(identifier);
  if (iterator == registry.contexts.end()) {
    return false;
  }
  *context = std::move(iterator->second);
  registry.contexts.erase(iterator);
  return true;
}

void RemoveActionCompletions(
    const std::shared_ptr<bool> &lifecycle_token) {
  ActionCompletionRegistry &registry = GetActionCompletionRegistry();
  std::lock_guard<std::mutex> lock(registry.mutex);
  for (auto iterator = registry.contexts.begin();
       iterator != registry.contexts.end();) {
    const std::weak_ptr<bool> &candidate =
        iterator->second.lifecycle_token;
    const bool has_same_owner =
        !candidate.owner_before(lifecycle_token) &&
        !lifecycle_token.owner_before(candidate);
    if (has_same_owner) {
      iterator = registry.contexts.erase(iterator);
    } else {
      ++iterator;
    }
  }
}

size_t ActionCompletionCount() {
  ActionCompletionRegistry &registry = GetActionCompletionRegistry();
  std::lock_guard<std::mutex> lock(registry.mutex);
  return registry.contexts.size();
}

} // namespace

NativeSelectableTextMenuHost::NativeSelectableTextMenuHost(
    FlBinaryMessenger *messenger, GtkWidget *flutter_view)
    : NativeSelectableTextMenuHost(flutter_view, nullptr, nullptr) {
  flutter_api_ = oh_my_flutter_native_selectable_text_menu_flutter_api_new(
      messenger, nullptr);
  flutter_event_cancellable_ = g_cancellable_new();
}

NativeSelectableTextMenuHost::NativeSelectableTextMenuHost(
    GtkWidget *flutter_view,
    std::function<void(int64_t, int64_t, std::function<void()>)> on_action,
    std::function<void(int64_t, bool)> on_dismissed)
    : on_action_(std::move(on_action)), on_dismissed_(std::move(on_dismissed)) {
  GObject *view_object =
      flutter_view == nullptr ? nullptr : G_OBJECT(flutter_view);
  g_weak_ref_init(&flutter_view_, view_object);
}

NativeSelectableTextMenuHost::~NativeSelectableTextMenuHost() {
  RemoveActionCompletions(lifecycle_token_);
  lifecycle_token_.reset();
  if (flutter_event_cancellable_ != nullptr) {
    g_cancellable_cancel(flutter_event_cancellable_);
  }
  if (presentation_source_identifier_ != 0) {
    g_source_remove(presentation_source_identifier_);
    presentation_source_identifier_ = 0;
  }

  suppress_active_dismissal_ = true;
  if (active_menu_ != nullptr) {
    GtkWidget *menu = active_menu_;
    PopdownActiveMenu();
    if (active_menu_ == menu) {
      active_menu_ = nullptr;
      DestroyOwnedMenu(menu);
    }
  }
  g_clear_object(&active_request_);
  reuse_active_menu_for_pending_ = false;
  DestroyPendingMenu();
  g_clear_object(&flutter_api_);
  g_clear_object(&flutter_event_cancellable_);
  g_weak_ref_clear(&flutter_view_);
}

OhMyFlutterNativeSelectableTextMenuHostApiShowResponse *
NativeSelectableTextMenuHost::Show(
    OhMyFlutterNativeSelectableTextMenuRequestMessage *request,
    gpointer user_data) {
  auto *host = static_cast<NativeSelectableTextMenuHost *>(user_data);
  return oh_my_flutter_native_selectable_text_menu_host_api_show_response_new(
      host->HandleShow(request));
}

OhMyFlutterNativeSelectableTextMenuHostApiUpdateResponse *
NativeSelectableTextMenuHost::Update(
    OhMyFlutterNativeSelectableTextMenuRequestMessage *request,
    gpointer user_data) {
  auto *host = static_cast<NativeSelectableTextMenuHost *>(user_data);
  return oh_my_flutter_native_selectable_text_menu_host_api_update_response_new(
      host->HandleUpdate(request));
}

OhMyFlutterNativeSelectableTextMenuHostApiUpdateGeometryResponse *
NativeSelectableTextMenuHost::UpdateGeometry(int64_t session_identifier,
                                             const double *geometry,
                                             size_t geometry_length,
                                             gpointer user_data) {
  auto *host = static_cast<NativeSelectableTextMenuHost *>(user_data);
  return oh_my_flutter_native_selectable_text_menu_host_api_update_geometry_response_new(
      host->HandleUpdateGeometry(session_identifier, geometry,
                                 geometry_length));
}

OhMyFlutterNativeSelectableTextMenuHostApiHideResponse *
NativeSelectableTextMenuHost::Hide(int64_t session_identifier,
                                   gpointer user_data) {
  auto *host = static_cast<NativeSelectableTextMenuHost *>(user_data);
  host->HandleHide(session_identifier);
  return oh_my_flutter_native_selectable_text_menu_host_api_hide_response_new();
}

bool NativeSelectableTextMenuHost::HasNativeHost() const {
  return NativeWindow() != nullptr;
}

GdkWindow *NativeSelectableTextMenuHost::NativeWindow() const {
  g_autoptr(GObject) view_object = G_OBJECT(g_weak_ref_get(&flutter_view_));
  if (view_object == nullptr) {
    return nullptr;
  }

  GtkWidget *view = GTK_WIDGET(view_object);
  return gtk_widget_get_realized(view) ? gtk_widget_get_window(view) : nullptr;
}

bool NativeSelectableTextMenuHost::SchedulePresentation() {
  presentation_source_identifier_ = g_idle_add_full(
      G_PRIORITY_DEFAULT_IDLE, PresentPendingMenuCallback, this, nullptr);
  return presentation_source_identifier_ != 0;
}

void NativeSelectableTextMenuHost::PopdownActiveMenu() {
  gtk_menu_popdown(GTK_MENU(active_menu_));
}

void NativeSelectableTextMenuHost::PopupNativeMenu(
    GtkWidget *menu, GdkWindow *window, const GdkRectangle &anchor_rectangle) {
  gtk_menu_popup_at_rect(GTK_MENU(menu), window, &anchor_rectangle,
                         GDK_GRAVITY_SOUTH_WEST, GDK_GRAVITY_NORTH_WEST,
                         nullptr);
}

void NativeSelectableTextMenuHost::PresentPendingMenu() {
  if (active_menu_ != nullptr || pending_menu_ == nullptr ||
      pending_request_ == nullptr) {
    return;
  }

  GdkWindow *window = NativeWindow();
  if (window == nullptr) {
    const int64_t session_identifier =
        oh_my_flutter_native_selectable_text_menu_request_message_get_session_identifier(
            pending_request_);
    DestroyPendingMenu();
    SendDismissed(session_identifier, false);
    return;
  }

  OhMyFlutterNativeSelectableTextMenuRequestMessage *request = pending_request_;
  GtkWidget *menu = pending_menu_;
  pending_request_ = nullptr;
  pending_menu_ = nullptr;

  active_menu_ = menu;
  active_request_ = request;
  active_geometry_ = pending_geometry_;
  active_session_identifier_ =
      oh_my_flutter_native_selectable_text_menu_request_message_get_session_identifier(
          request);
  active_action_invoked_ = false;
  active_action_identifier_ = 0;
  suppress_active_dismissal_ = false;

  const GdkRectangle anchor_rectangle = {
      static_cast<int>(std::lround(active_geometry_[kGeometryAnchorDxIndex])),
      static_cast<int>(std::lround(active_geometry_[kGeometryAnchorDyIndex])),
      1,
      1,
  };
  gtk_widget_show_all(menu);
  PopupNativeMenu(menu, window, anchor_rectangle);
}

bool NativeSelectableTextMenuHost::HandleShow(
    OhMyFlutterNativeSelectableTextMenuRequestMessage *request) {
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
    GtkWidget *menu = active_menu_;
    PopdownActiveMenu();
    if (active_menu_ == menu) {
      FinishActiveMenu(GTK_MENU_SHELL(menu));
    }
    return true;
  }

  if (!QueuePendingPresentation()) {
    DestroyPendingMenu();
    return false;
  }

  return true;
}

bool NativeSelectableTextMenuHost::HandleUpdate(
    OhMyFlutterNativeSelectableTextMenuRequestMessage *request) {
  const int64_t session_identifier =
      oh_my_flutter_native_selectable_text_menu_request_message_get_session_identifier(
          request);
  if (!IsCurrentSession(session_identifier)) {
    return false;
  }
  if (!HasNativeHost() || !IsValidRequest(request)) {
    ClearSessionSilently(session_identifier);
    return false;
  }

  const Geometry geometry = GeometryFromRequest(request);
  if (pending_request_ != nullptr) {
    if (MenuItemsEqual(pending_request_, request)) {
      if (pending_geometry_ == geometry) {
        return true;
      }
      ReplacePendingRequest(request);
      return true;
    }
  } else if (active_request_ != nullptr) {
    if (MenuItemsEqual(active_request_, request)) {
      if (active_geometry_ == geometry) {
        return true;
      }
      if (!QueuePendingPresentation()) {
        ClearSessionSilently(session_identifier);
        return false;
      }
      ReplacePendingRequest(request);
      reuse_active_menu_for_pending_ = true;
      suppress_active_dismissal_ = true;
      GtkWidget *menu = active_menu_;
      PopdownActiveMenu();
      if (active_menu_ == menu) {
        FinishActiveMenu(GTK_MENU_SHELL(menu));
      }
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
    GtkWidget *menu = active_menu_;
    PopdownActiveMenu();
    if (active_menu_ == menu) {
      FinishActiveMenu(GTK_MENU_SHELL(menu));
    }
    return true;
  }

  if (!QueuePendingPresentation()) {
    DestroyPendingMenu();
    return false;
  }

  return true;
}

bool NativeSelectableTextMenuHost::HandleUpdateGeometry(
    int64_t session_identifier, const double *geometry,
    size_t geometry_length) {
  if (!IsCurrentSession(session_identifier)) {
    return false;
  }
  if (geometry == nullptr || geometry_length != kGeometryValueCount) {
    ClearSessionSilently(session_identifier);
    return false;
  }

  const Geometry next_geometry = {
      geometry[kGeometryLeftIndex],     geometry[kGeometryTopIndex],
      geometry[kGeometryRightIndex],    geometry[kGeometryBottomIndex],
      geometry[kGeometryAnchorDxIndex], geometry[kGeometryAnchorDyIndex],
  };
  if (!HasNativeHost() || !IsValidGeometry(next_geometry)) {
    ClearSessionSilently(session_identifier);
    return false;
  }

  if (pending_request_ != nullptr) {
    if (oh_my_flutter_native_selectable_text_menu_request_message_get_session_identifier(
            pending_request_) != session_identifier) {
      return false;
    }
    pending_geometry_ = next_geometry;
    return true;
  }
  if (active_request_ == nullptr ||
      active_session_identifier_ != session_identifier) {
    return false;
  }
  if (active_geometry_ == next_geometry) {
    return true;
  }
  if (!QueuePendingPresentation()) {
    ClearSessionSilently(session_identifier);
    return false;
  }

  ReplacePendingRequest(active_request_);
  pending_geometry_ = next_geometry;
  reuse_active_menu_for_pending_ = true;
  suppress_active_dismissal_ = true;
  GtkWidget *menu = active_menu_;
  PopdownActiveMenu();
  if (active_menu_ == menu) {
    FinishActiveMenu(GTK_MENU_SHELL(menu));
  }
  return true;
}

void NativeSelectableTextMenuHost::HandleHide(int64_t session_identifier) {
  if (pending_request_ != nullptr &&
      oh_my_flutter_native_selectable_text_menu_request_message_get_session_identifier(
          pending_request_) == session_identifier) {
    DestroyPendingMenu();
  }

  if (active_menu_ != nullptr &&
      active_session_identifier_ == session_identifier) {
    suppress_active_dismissal_ = true;
    GtkWidget *menu = active_menu_;
    PopdownActiveMenu();
    if (active_menu_ == menu) {
      FinishActiveMenu(GTK_MENU_SHELL(menu));
    }
  }
}

size_t NativeSelectableTextMenuHost::
    OutstandingActionCompletionCountForTesting() {
  return ActionCompletionCount();
}

bool NativeSelectableTextMenuHost::ReplacePendingMenu(
    OhMyFlutterNativeSelectableTextMenuRequestMessage *request) {
  GtkWidget *menu = BuildMenu(request);
  if (menu == nullptr) {
    return false;
  }

  DestroyPendingMenu();
  pending_request_ = OH_MY_FLUTTER_NATIVE_SELECTABLE_TEXT_MENU_REQUEST_MESSAGE(
      g_object_ref(request));
  pending_geometry_ = GeometryFromRequest(request);
  pending_menu_ = menu;
  return true;
}

void NativeSelectableTextMenuHost::ReplacePendingRequest(
    OhMyFlutterNativeSelectableTextMenuRequestMessage *request) {
  OhMyFlutterNativeSelectableTextMenuRequestMessage *replacement =
      OH_MY_FLUTTER_NATIVE_SELECTABLE_TEXT_MENU_REQUEST_MESSAGE(
          g_object_ref(request));
  g_clear_object(&pending_request_);
  pending_request_ = replacement;
  pending_geometry_ = GeometryFromRequest(request);
}

bool NativeSelectableTextMenuHost::QueuePendingPresentation() {
  if (presentation_source_identifier_ != 0) {
    return true;
  }
  return SchedulePresentation();
}

bool NativeSelectableTextMenuHost::IsCurrentSession(
    int64_t session_identifier) const {
  if (pending_request_ != nullptr &&
      oh_my_flutter_native_selectable_text_menu_request_message_get_session_identifier(
          pending_request_) == session_identifier) {
    return true;
  }

  return active_menu_ != nullptr &&
         active_session_identifier_ == session_identifier;
}

bool NativeSelectableTextMenuHost::IsValidRequest(
    OhMyFlutterNativeSelectableTextMenuRequestMessage *request) const {
  FlValue *items =
      oh_my_flutter_native_selectable_text_menu_request_message_get_items(
          request);
  return fl_value_get_type(items) == FL_VALUE_TYPE_LIST &&
         fl_value_get_length(items) > 0 &&
         IsValidGeometry(GeometryFromRequest(request));
}

bool NativeSelectableTextMenuHost::IsValidGeometry(
    const Geometry &geometry) {
  return std::isfinite(geometry[kGeometryLeftIndex]) &&
         std::isfinite(geometry[kGeometryTopIndex]) &&
         std::isfinite(geometry[kGeometryRightIndex]) &&
         std::isfinite(geometry[kGeometryBottomIndex]) &&
         geometry[kGeometryRightIndex] >= geometry[kGeometryLeftIndex] &&
         geometry[kGeometryBottomIndex] >= geometry[kGeometryTopIndex] &&
         std::isfinite(geometry[kGeometryAnchorDxIndex]) &&
         std::isfinite(geometry[kGeometryAnchorDyIndex]);
}

NativeSelectableTextMenuHost::Geometry
NativeSelectableTextMenuHost::GeometryFromRequest(
    OhMyFlutterNativeSelectableTextMenuRequestMessage *request) {
  OhMyFlutterNativeSelectableTextRectangleMessage *rectangle =
      oh_my_flutter_native_selectable_text_menu_request_message_get_selection_rectangle(
          request);
  OhMyFlutterNativeSelectableTextPointMessage *anchor =
      oh_my_flutter_native_selectable_text_menu_request_message_get_primary_anchor(
          request);
  return {
      oh_my_flutter_native_selectable_text_rectangle_message_get_left(
          rectangle),
      oh_my_flutter_native_selectable_text_rectangle_message_get_top(rectangle),
      oh_my_flutter_native_selectable_text_rectangle_message_get_right(
          rectangle),
      oh_my_flutter_native_selectable_text_rectangle_message_get_bottom(
          rectangle),
      oh_my_flutter_native_selectable_text_point_message_get_dx(anchor),
      oh_my_flutter_native_selectable_text_point_message_get_dy(anchor),
  };
}

bool NativeSelectableTextMenuHost::MenuItemsEqual(
    OhMyFlutterNativeSelectableTextMenuRequestMessage *first,
    OhMyFlutterNativeSelectableTextMenuRequestMessage *second) const {
  FlValue *first_items =
      oh_my_flutter_native_selectable_text_menu_request_message_get_items(
          first);
  FlValue *second_items =
      oh_my_flutter_native_selectable_text_menu_request_message_get_items(
          second);
  if (fl_value_get_type(first_items) != FL_VALUE_TYPE_LIST ||
      fl_value_get_type(second_items) != FL_VALUE_TYPE_LIST ||
      fl_value_get_length(first_items) != fl_value_get_length(second_items)) {
    return false;
  }

  for (size_t index = 0; index < fl_value_get_length(first_items); ++index) {
    FlValue *first_value = fl_value_get_list_value(first_items, index);
    FlValue *second_value = fl_value_get_list_value(second_items, index);
    if (fl_value_get_type(first_value) != FL_VALUE_TYPE_CUSTOM ||
        fl_value_get_type(second_value) != FL_VALUE_TYPE_CUSTOM ||
        fl_value_get_custom_type(first_value) !=
            oh_my_flutter_native_selectable_text_menu_item_message_type_id ||
        fl_value_get_custom_type(second_value) !=
            oh_my_flutter_native_selectable_text_menu_item_message_type_id) {
      return false;
    }

    auto *first_item =
        OH_MY_FLUTTER_NATIVE_SELECTABLE_TEXT_MENU_ITEM_MESSAGE(
            fl_value_get_custom_value_object(first_value));
    auto *second_item =
        OH_MY_FLUTTER_NATIVE_SELECTABLE_TEXT_MENU_ITEM_MESSAGE(
            fl_value_get_custom_value_object(second_value));
    if (oh_my_flutter_native_selectable_text_menu_item_message_get_identifier(
            first_item) !=
            oh_my_flutter_native_selectable_text_menu_item_message_get_identifier(
                second_item) ||
        g_strcmp0(
            oh_my_flutter_native_selectable_text_menu_item_message_get_label(
                first_item),
            oh_my_flutter_native_selectable_text_menu_item_message_get_label(
                second_item)) != 0) {
      return false;
    }
  }

  return true;
}

GtkWidget *NativeSelectableTextMenuHost::BuildMenu(
    OhMyFlutterNativeSelectableTextMenuRequestMessage *request) const {
  FlValue *items =
      oh_my_flutter_native_selectable_text_menu_request_message_get_items(
          request);
  if (fl_value_get_type(items) != FL_VALUE_TYPE_LIST ||
      fl_value_get_length(items) == 0) {
    return nullptr;
  }

  GtkWidget *menu = gtk_menu_new();
  g_object_ref_sink(menu);
  g_signal_connect(menu, "selection-done",
                   G_CALLBACK(MenuSelectionDoneCallback),
                   const_cast<NativeSelectableTextMenuHost *>(this));

  for (size_t index = 0; index < fl_value_get_length(items); ++index) {
    FlValue *value = fl_value_get_list_value(items, index);
    if (fl_value_get_type(value) != FL_VALUE_TYPE_CUSTOM ||
        fl_value_get_custom_type(value) !=
            oh_my_flutter_native_selectable_text_menu_item_message_type_id) {
      DestroyOwnedMenu(menu);
      return nullptr;
    }

    auto *item_message = OH_MY_FLUTTER_NATIVE_SELECTABLE_TEXT_MENU_ITEM_MESSAGE(
        fl_value_get_custom_value_object(value));
    const gchar *label =
        oh_my_flutter_native_selectable_text_menu_item_message_get_label(
            item_message);
    if (!HasVisibleLabel(label)) {
      DestroyOwnedMenu(menu);
      return nullptr;
    }

    GtkWidget *item = gtk_menu_item_new_with_label(label);
    auto *action_identifier = g_new(int64_t, 1);
    *action_identifier =
        oh_my_flutter_native_selectable_text_menu_item_message_get_identifier(
            item_message);
    g_object_set_data_full(G_OBJECT(item), kActionIdentifierKey,
                           action_identifier, g_free);
    g_signal_connect(item, "activate", G_CALLBACK(MenuItemActivatedCallback),
                     const_cast<NativeSelectableTextMenuHost *>(this));
    gtk_menu_shell_append(GTK_MENU_SHELL(menu), item);
  }

  return menu;
}

void NativeSelectableTextMenuHost::ClearAllMenusSilently() {
  DestroyPendingMenu();
  if (active_menu_ == nullptr) {
    return;
  }
  suppress_active_dismissal_ = true;
  GtkWidget *menu = active_menu_;
  PopdownActiveMenu();
  if (active_menu_ == menu) {
    FinishActiveMenu(GTK_MENU_SHELL(menu));
  }
}

void NativeSelectableTextMenuHost::ClearSessionSilently(
    int64_t session_identifier) {
  if (pending_request_ != nullptr &&
      oh_my_flutter_native_selectable_text_menu_request_message_get_session_identifier(
          pending_request_) == session_identifier) {
    DestroyPendingMenu();
  }
  if (active_menu_ == nullptr ||
      active_session_identifier_ != session_identifier) {
    return;
  }
  suppress_active_dismissal_ = true;
  GtkWidget *menu = active_menu_;
  PopdownActiveMenu();
  if (active_menu_ == menu) {
    FinishActiveMenu(GTK_MENU_SHELL(menu));
  }
}

void NativeSelectableTextMenuHost::DestroyPendingMenu() {
  g_clear_object(&pending_request_);
  reuse_active_menu_for_pending_ = false;
  if (pending_menu_ != nullptr) {
    GtkWidget *menu = pending_menu_;
    pending_menu_ = nullptr;
    DestroyOwnedMenu(menu);
  }
}

void NativeSelectableTextMenuHost::DestroyOwnedMenu(GtkWidget *menu) const {
  gtk_widget_destroy(menu);
  g_object_unref(menu);
}

void NativeSelectableTextMenuHost::FinishActiveMenu(GtkMenuShell *menu) {
  if (active_menu_ != GTK_WIDGET(menu)) {
    return;
  }

  GtkWidget *owned_menu = active_menu_;
  const int64_t session_identifier = active_session_identifier_;
  const int64_t action_identifier = active_action_identifier_;
  const bool action_invoked = active_action_invoked_;
  const bool should_report = !suppress_active_dismissal_;
  const bool should_reuse_menu =
      reuse_active_menu_for_pending_ && pending_request_ != nullptr &&
      !should_report;
  active_menu_ = nullptr;
  g_clear_object(&active_request_);
  active_session_identifier_ = 0;
  active_action_identifier_ = 0;
  active_action_invoked_ = false;
  suppress_active_dismissal_ = false;
  reuse_active_menu_for_pending_ = false;
  if (should_reuse_menu) {
    pending_menu_ = owned_menu;
  } else {
    DestroyOwnedMenu(owned_menu);
  }

  if (should_report) {
    if (action_invoked) {
      SendAction(session_identifier, action_identifier);
    } else {
      SendDismissed(session_identifier, false);
    }
  }

  if (pending_menu_ != nullptr && presentation_source_identifier_ == 0 &&
      !QueuePendingPresentation()) {
    DestroyPendingMenu();
  }
}

void NativeSelectableTextMenuHost::SendAction(int64_t session_identifier,
                                              int64_t action_identifier) {
  if (flutter_api_ != nullptr) {
    gpointer completion_identifier =
        RegisterActionCompletion(session_identifier, lifecycle_token_);
    oh_my_flutter_native_selectable_text_menu_flutter_api_on_action(
        flutter_api_, session_identifier, action_identifier,
        flutter_event_cancellable_, ActionCompletedCallback,
        completion_identifier);
    return;
  }
  if (on_action_) {
    const auto on_dismissed = on_dismissed_;
    const std::weak_ptr<bool> lifecycle_token = lifecycle_token_;
    on_action_(session_identifier, action_identifier,
               [on_dismissed, session_identifier, lifecycle_token] {
                 if (!lifecycle_token.expired() && on_dismissed) {
                   on_dismissed(session_identifier, true);
                 }
               });
    return;
  }
  if (on_dismissed_) {
    on_dismissed_(session_identifier, true);
  }
}

void NativeSelectableTextMenuHost::SendDismissed(int64_t session_identifier,
                                                 bool action_invoked) {
  if (flutter_api_ != nullptr) {
    oh_my_flutter_native_selectable_text_menu_flutter_api_on_dismissed(
        flutter_api_, session_identifier, action_invoked,
        flutter_event_cancellable_, DismissalCompletedCallback, nullptr);
  }
  if (on_dismissed_) {
    on_dismissed_(session_identifier, action_invoked);
  }
}

gboolean
NativeSelectableTextMenuHost::PresentPendingMenuCallback(gpointer user_data) {
  auto *host = static_cast<NativeSelectableTextMenuHost *>(user_data);
  host->presentation_source_identifier_ = 0;
  host->PresentPendingMenu();
  return G_SOURCE_REMOVE;
}

void NativeSelectableTextMenuHost::MenuItemActivatedCallback(
    GtkMenuItem *item, gpointer user_data) {
  auto *host = static_cast<NativeSelectableTextMenuHost *>(user_data);
  if (host->active_menu_ == nullptr || host->suppress_active_dismissal_) {
    return;
  }

  const auto *action_identifier = static_cast<const int64_t *>(
      g_object_get_data(G_OBJECT(item), kActionIdentifierKey));
  if (action_identifier == nullptr) {
    return;
  }

  host->active_action_invoked_ = true;
  host->active_action_identifier_ = *action_identifier;
}

void NativeSelectableTextMenuHost::MenuSelectionDoneCallback(
    GtkMenuShell *menu, gpointer user_data) {
  auto *host = static_cast<NativeSelectableTextMenuHost *>(user_data);
  host->FinishActiveMenu(menu);
}

void NativeSelectableTextMenuHost::ActionCompletedCallback(GObject *object,
                                                           GAsyncResult *result,
                                                           gpointer user_data) {
  GCancellable *task_cancellable = g_task_get_cancellable(G_TASK(result));
  g_autoptr(GCancellable) event_cancellable =
      task_cancellable == nullptr
          ? nullptr
          : G_CANCELLABLE(g_object_ref(task_cancellable));
  g_autoptr(
      OhMyFlutterNativeSelectableTextMenuFlutterApiOnActionResponse) response =
      oh_my_flutter_native_selectable_text_menu_flutter_api_on_action_finish(
          OH_MY_FLUTTER_NATIVE_SELECTABLE_TEXT_MENU_FLUTTER_API(object), result,
          nullptr);
  (void)response;
  ActionCompletionContext completion_context = {};
  if (!TakeActionCompletion(user_data, &completion_context) ||
      completion_context.lifecycle_token.expired()) {
    return;
  }
  oh_my_flutter_native_selectable_text_menu_flutter_api_on_dismissed(
      OH_MY_FLUTTER_NATIVE_SELECTABLE_TEXT_MENU_FLUTTER_API(object),
      completion_context.session_identifier, true,
      event_cancellable, DismissalCompletedCallback, nullptr);
}

void NativeSelectableTextMenuHost::DismissalCompletedCallback(
    GObject *object, GAsyncResult *result, gpointer) {
  g_autoptr(
      OhMyFlutterNativeSelectableTextMenuFlutterApiOnDismissedResponse) response =
      oh_my_flutter_native_selectable_text_menu_flutter_api_on_dismissed_finish(
          OH_MY_FLUTTER_NATIVE_SELECTABLE_TEXT_MENU_FLUTTER_API(object), result,
          nullptr);
  (void)response;
}

} // namespace oh_my_flutter
