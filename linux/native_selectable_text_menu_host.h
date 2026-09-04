#ifndef FLUTTER_PLUGIN_NATIVE_SELECTABLE_TEXT_MENU_HOST_H_
#define FLUTTER_PLUGIN_NATIVE_SELECTABLE_TEXT_MENU_HOST_H_

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

#include <array>
#include <cstddef>
#include <cstdint>
#include <functional>
#include <memory>

#include "native_selectable_text.g.h"

namespace oh_my_flutter {

// Owns a single native GTK selection menu for one Flutter engine.
class NativeSelectableTextMenuHost {
public:
  NativeSelectableTextMenuHost(FlBinaryMessenger *messenger,
                               GtkWidget *flutter_view);
  NativeSelectableTextMenuHost(
      GtkWidget *flutter_view,
      std::function<void(int64_t, int64_t, std::function<void()>)> on_action,
      std::function<void(int64_t, bool)> on_dismissed);
  virtual ~NativeSelectableTextMenuHost();

  NativeSelectableTextMenuHost(const NativeSelectableTextMenuHost &) = delete;
  NativeSelectableTextMenuHost &
  operator=(const NativeSelectableTextMenuHost &) = delete;

  static OhMyFlutterNativeSelectableTextMenuHostApiShowResponse *
  Show(OhMyFlutterNativeSelectableTextMenuRequestMessage *request,
       gpointer user_data);
  static OhMyFlutterNativeSelectableTextMenuHostApiUpdateResponse *
  Update(OhMyFlutterNativeSelectableTextMenuRequestMessage *request,
         gpointer user_data);
  static OhMyFlutterNativeSelectableTextMenuHostApiUpdateGeometryResponse *
  UpdateGeometry(int64_t session_identifier, const double *geometry,
                 size_t geometry_length, gpointer user_data);
  static OhMyFlutterNativeSelectableTextMenuHostApiHideResponse *
  Hide(int64_t session_identifier, gpointer user_data);

  bool HandleShow(OhMyFlutterNativeSelectableTextMenuRequestMessage *request);
  bool HandleUpdate(OhMyFlutterNativeSelectableTextMenuRequestMessage *request);
  bool HandleUpdateGeometry(int64_t session_identifier, const double *geometry,
                            size_t geometry_length);
  void HandleHide(int64_t session_identifier);

  // Returns plugin-owned action completions that are awaiting a Dart reply.
  static size_t OutstandingActionCompletionCountForTesting();

protected:
  virtual bool HasNativeHost() const;
  virtual GdkWindow *NativeWindow() const;
  virtual bool SchedulePresentation();
  virtual void PopdownActiveMenu();
  virtual void PopupNativeMenu(GtkWidget *menu, GdkWindow *window,
                               const GdkRectangle &anchor_rectangle);

  // Runs a queued presentation. Exposed to platform tests through a subclass.
  void PresentPendingMenu();
  virtual void DestroyOwnedMenu(GtkWidget *menu) const;

private:
  using Geometry = std::array<double, 6>;

  bool ReplacePendingMenu(
      OhMyFlutterNativeSelectableTextMenuRequestMessage *request);
  void ReplacePendingRequest(
      OhMyFlutterNativeSelectableTextMenuRequestMessage *request);
  bool QueuePendingPresentation();
  bool IsCurrentSession(int64_t session_identifier) const;
  bool IsValidRequest(
      OhMyFlutterNativeSelectableTextMenuRequestMessage *request) const;
  static bool IsValidGeometry(const Geometry &geometry);
  static Geometry GeometryFromRequest(
      OhMyFlutterNativeSelectableTextMenuRequestMessage *request);
  bool MenuItemsEqual(
      OhMyFlutterNativeSelectableTextMenuRequestMessage *first,
      OhMyFlutterNativeSelectableTextMenuRequestMessage *second) const;
  GtkWidget *
  BuildMenu(OhMyFlutterNativeSelectableTextMenuRequestMessage *request) const;
  void ClearAllMenusSilently();
  void ClearSessionSilently(int64_t session_identifier);
  void DestroyPendingMenu();
  void FinishActiveMenu(GtkMenuShell *menu);
  void SendAction(int64_t session_identifier, int64_t action_identifier);
  void SendDismissed(int64_t session_identifier, bool action_invoked);

  static gboolean PresentPendingMenuCallback(gpointer user_data);
  static void MenuItemActivatedCallback(GtkMenuItem *item, gpointer user_data);
  static void MenuSelectionDoneCallback(GtkMenuShell *menu, gpointer user_data);
  static void ActionCompletedCallback(GObject *object, GAsyncResult *result,
                                      gpointer user_data);
  static void DismissalCompletedCallback(GObject *object, GAsyncResult *result,
                                         gpointer user_data);

  mutable GWeakRef flutter_view_;
  OhMyFlutterNativeSelectableTextMenuFlutterApi *flutter_api_ = nullptr;
  GCancellable *flutter_event_cancellable_ = nullptr;
  std::function<void(int64_t, int64_t, std::function<void()>)> on_action_;
  std::function<void(int64_t, bool)> on_dismissed_;
  std::shared_ptr<bool> lifecycle_token_ = std::make_shared<bool>(true);

  OhMyFlutterNativeSelectableTextMenuRequestMessage *pending_request_ = nullptr;
  Geometry pending_geometry_ = {};
  GtkWidget *pending_menu_ = nullptr;
  guint presentation_source_identifier_ = 0;

  GtkWidget *active_menu_ = nullptr;
  OhMyFlutterNativeSelectableTextMenuRequestMessage *active_request_ = nullptr;
  Geometry active_geometry_ = {};
  int64_t active_session_identifier_ = 0;
  int64_t active_action_identifier_ = 0;
  bool active_action_invoked_ = false;
  bool suppress_active_dismissal_ = false;
  bool reuse_active_menu_for_pending_ = false;
};

} // namespace oh_my_flutter

#endif // FLUTTER_PLUGIN_NATIVE_SELECTABLE_TEXT_MENU_HOST_H_
