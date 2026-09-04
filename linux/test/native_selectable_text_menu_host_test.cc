#include <flutter_linux/flutter_linux.h>
#include <gtest/gtest.h>
#include <gtk/gtk.h>

#include <cstdint>
#include <limits>
#include <memory>
#include <string>
#include <tuple>
#include <utility>
#include <vector>

#include "native_selectable_text_menu_host.h"

namespace oh_my_flutter {
namespace test {

namespace {

OhMyFlutterNativeSelectableTextMenuRequestMessage *
MakeRequest(int64_t session_identifier, int64_t action_identifier,
            double anchor_dx = 3.25, const gchar *label = "Copy") {
  g_autoptr(OhMyFlutterNativeSelectableTextRectangleMessage) rectangle =
      oh_my_flutter_native_selectable_text_rectangle_message_new(1.0, 2.0, 8.0,
                                                                 9.0);
  g_autoptr(OhMyFlutterNativeSelectableTextPointMessage) anchor =
      oh_my_flutter_native_selectable_text_point_message_new(anchor_dx, 4.75);
  g_autoptr(OhMyFlutterNativeSelectableTextMenuItemMessage) item =
      oh_my_flutter_native_selectable_text_menu_item_message_new(
          action_identifier, label);
  g_autoptr(FlValue) items = fl_value_new_list();
  fl_value_append_take(
      items, fl_value_new_custom_object(
                 oh_my_flutter_native_selectable_text_menu_item_message_type_id,
                 G_OBJECT(item)));
  return oh_my_flutter_native_selectable_text_menu_request_message_new(
      session_identifier, rectangle, anchor, items);
}

std::vector<double> MakeGeometry(double left = 1.0, double top = 2.0,
                                 double right = 8.0, double bottom = 9.0,
                                 double anchor_dx = 3.25,
                                 double anchor_dy = 4.75) {
  return {left, top, right, bottom, anchor_dx, anchor_dy};
}

bool EnsureGtk() {
  static const bool initialized = [] {
    int argument_count = 0;
    return gtk_init_check(&argument_count, nullptr) == TRUE;
  }();
  return initialized;
}

void MarkMenuDestroyed(GtkWidget *, gpointer user_data) {
  *static_cast<bool *>(user_data) = true;
}

struct NoReplyBinaryMessenger {
  GObject parent_instance;
  GAsyncReadyCallback pending_callback = nullptr;
  gpointer pending_user_data = nullptr;
  GCancellable *pending_cancellable = nullptr;
  gulong pending_cancellation_handler = 0;
  bool completes_on_cancellation;
  int send_count = 0;
};

struct NoReplyBinaryMessengerClass {
  GObjectClass parent_class;
};

void NoReplyBinaryMessengerInterfaceInit(FlBinaryMessengerInterface *interface);

G_DEFINE_TYPE_WITH_CODE(
    NoReplyBinaryMessenger, no_reply_binary_messenger, G_TYPE_OBJECT,
    G_IMPLEMENT_INTERFACE(fl_binary_messenger_get_type(),
                          NoReplyBinaryMessengerInterfaceInit))

void NoReplyBinaryMessengerSetMessageHandler(
    FlBinaryMessenger *, const gchar *, FlBinaryMessengerMessageHandler,
    gpointer user_data, GDestroyNotify destroy_notify) {
  if (destroy_notify != nullptr) {
    destroy_notify(user_data);
  }
}

gboolean NoReplyBinaryMessengerSendResponse(
    FlBinaryMessenger *, FlBinaryMessengerResponseHandle *, GBytes *,
    GError **) {
  return TRUE;
}

void CancelPendingMessage(GCancellable *cancellable, gpointer user_data) {
  auto *self = static_cast<NoReplyBinaryMessenger *>(user_data);
  GAsyncReadyCallback callback = self->pending_callback;
  gpointer callback_user_data = self->pending_user_data;
  self->pending_callback = nullptr;
  self->pending_user_data = nullptr;
  self->pending_cancellation_handler = 0;
  g_clear_object(&self->pending_cancellable);

  g_autoptr(GTask) task =
      g_task_new(self, cancellable, callback, callback_user_data);
  g_task_return_new_error(task, G_IO_ERROR, G_IO_ERROR_CANCELLED,
                          "The native menu host was destroyed");
}

void NoReplyBinaryMessengerSendOnChannel(
    FlBinaryMessenger *messenger, const gchar *, GBytes *,
    GCancellable *cancellable, GAsyncReadyCallback callback,
    gpointer user_data) {
  auto *self = reinterpret_cast<NoReplyBinaryMessenger *>(messenger);
  ++self->send_count;
  self->pending_callback = callback;
  self->pending_user_data = user_data;
  g_set_object(&self->pending_cancellable, cancellable);
  if (cancellable != nullptr && self->completes_on_cancellation) {
    self->pending_cancellation_handler = g_cancellable_connect(
        cancellable, G_CALLBACK(CancelPendingMessage), self, nullptr);
  }
}

GBytes *NoReplyBinaryMessengerSendOnChannelFinish(
    FlBinaryMessenger *, GAsyncResult *result, GError **error) {
  return static_cast<GBytes *>(
      g_task_propagate_pointer(G_TASK(result), error));
}

void NoReplyBinaryMessengerResizeChannel(FlBinaryMessenger *, const gchar *,
                                         int64_t) {}

void NoReplyBinaryMessengerSetWarnsOnChannelOverflow(FlBinaryMessenger *,
                                                     const gchar *, bool) {}

void NoReplyBinaryMessengerShutdown(FlBinaryMessenger *) {}

void NoReplyBinaryMessengerInterfaceInit(
    FlBinaryMessengerInterface *interface) {
  interface->set_message_handler_on_channel =
      NoReplyBinaryMessengerSetMessageHandler;
  interface->send_response = NoReplyBinaryMessengerSendResponse;
  interface->send_on_channel = NoReplyBinaryMessengerSendOnChannel;
  interface->send_on_channel_finish =
      NoReplyBinaryMessengerSendOnChannelFinish;
  interface->resize_channel = NoReplyBinaryMessengerResizeChannel;
  interface->set_warns_on_channel_overflow =
      NoReplyBinaryMessengerSetWarnsOnChannelOverflow;
  interface->shutdown = NoReplyBinaryMessengerShutdown;
}

void no_reply_binary_messenger_init(NoReplyBinaryMessenger *self) {
  self->completes_on_cancellation = true;
}

void no_reply_binary_messenger_class_init(NoReplyBinaryMessengerClass *) {}

NoReplyBinaryMessenger *MakeNoReplyBinaryMessenger() {
  return reinterpret_cast<NoReplyBinaryMessenger *>(
      g_object_new(no_reply_binary_messenger_get_type(), nullptr));
}

void CompletePendingMessage(NoReplyBinaryMessenger *messenger) {
  GAsyncReadyCallback callback = messenger->pending_callback;
  gpointer user_data = messenger->pending_user_data;
  messenger->pending_callback = nullptr;
  messenger->pending_user_data = nullptr;
  if (messenger->pending_cancellation_handler != 0) {
    g_cancellable_disconnect(messenger->pending_cancellable,
                             messenger->pending_cancellation_handler);
    messenger->pending_cancellation_handler = 0;
  }

  g_autoptr(FlStandardMessageCodec) codec =
      fl_standard_message_codec_new();
  g_autoptr(FlValue) response = fl_value_new_list();
  fl_value_append_take(response, fl_value_new_null());
  g_autoptr(GError) error = nullptr;
  g_autoptr(GBytes) bytes =
      fl_message_codec_encode_message(FL_MESSAGE_CODEC(codec), response, &error);
  EXPECT_EQ(error, nullptr);
  ASSERT_NE(bytes, nullptr);

  g_autoptr(GTask) task =
      g_task_new(messenger, messenger->pending_cancellable, callback, user_data);
  g_clear_object(&messenger->pending_cancellable);
  g_task_return_pointer(task, g_steal_pointer(&bytes),
                        reinterpret_cast<GDestroyNotify>(g_bytes_unref));
}

void DrainMainContext() {
  while (g_main_context_pending(nullptr)) {
    g_main_context_iteration(nullptr, FALSE);
  }
}

void MarkObjectFinalized(gpointer user_data, GObject *) {
  *static_cast<bool *>(user_data) = true;
}

class TestNativeSelectableTextMenuHost : public NativeSelectableTextMenuHost {
public:
  explicit TestNativeSelectableTextMenuHost(FlBinaryMessenger *messenger)
      : NativeSelectableTextMenuHost(messenger, nullptr) {}

  TestNativeSelectableTextMenuHost(
      std::function<void(int64_t, int64_t, std::function<void()>)> on_action,
      std::function<void(int64_t, bool)> on_dismissed)
      : NativeSelectableTextMenuHost(nullptr, std::move(on_action),
                                     std::move(on_dismissed)) {}

  int schedule_count = 0;
  int presentation_count = 0;
  mutable int destroyed_menu_count = 0;
  GdkRectangle presented_anchor = {};
  bool reused_first_menu = false;
  bool activate_first_item = false;
  bool host_available = true;
  bool native_window_available = true;
  bool schedule_succeeds = true;
  std::function<void()> during_presentation;

  void PresentNow() { PresentPendingMenu(); }

protected:
  bool HasNativeHost() const override { return host_available; }

  GdkWindow *NativeWindow() const override {
    return native_window_available ? reinterpret_cast<GdkWindow *>(1) : nullptr;
  }

  bool SchedulePresentation() override {
    ++schedule_count;
    return schedule_succeeds;
  }

  void PopdownActiveMenu() override {}

  void DestroyOwnedMenu(GtkWidget *menu) const override {
    ++destroyed_menu_count;
    NativeSelectableTextMenuHost::DestroyOwnedMenu(menu);
  }

  void PopupNativeMenu(GtkWidget *menu, GdkWindow *,
                       const GdkRectangle &anchor_rectangle) override {
    ++presentation_count;
    presented_anchor = anchor_rectangle;
    if (presentation_count == 1) {
      g_object_set_data(G_OBJECT(menu), "test-native-selectable-text-menu",
                        this);
    } else {
      reused_first_menu =
          g_object_get_data(G_OBJECT(menu),
                            "test-native-selectable-text-menu") == this;
    }
    g_object_ref(menu);
    bool menu_destroyed = false;
    const gulong destroy_handler =
        g_signal_connect(menu, "destroy", G_CALLBACK(MarkMenuDestroyed),
                         &menu_destroyed);
    if (during_presentation) {
      auto callback = std::move(during_presentation);
      callback();
    }
    if (!menu_destroyed) {
      if (activate_first_item) {
        GList *children = gtk_container_get_children(GTK_CONTAINER(menu));
        gtk_menu_item_activate(GTK_MENU_ITEM(children->data));
        g_list_free(children);
      }
      g_signal_emit_by_name(menu, "selection-done");
    }
    if (!menu_destroyed &&
        g_signal_handler_is_connected(menu, destroy_handler)) {
      g_signal_handler_disconnect(menu, destroy_handler);
    }
    g_object_unref(menu);
  }
};

} // namespace

TEST(NativeSelectableTextMenuHostTest,
     WhenAnActionNeverRepliesItShouldCancelAndReleaseMessengerOnTeardown) {
  if (!EnsureGtk()) {
    GTEST_SKIP() << "GTK requires a display";
  }
  bool messenger_finalized = false;
  NoReplyBinaryMessenger *messenger = MakeNoReplyBinaryMessenger();
  g_object_weak_ref(G_OBJECT(messenger), MarkObjectFinalized,
                    &messenger_finalized);
  auto host = std::make_unique<TestNativeSelectableTextMenuHost>(
      FL_BINARY_MESSENGER(messenger));
  g_object_unref(messenger);
  host->activate_first_item = true;
  g_autoptr(OhMyFlutterNativeSelectableTextMenuRequestMessage) request =
      MakeRequest(7, 42);

  ASSERT_TRUE(host->HandleShow(request));
  host->PresentNow();
  const bool received_cancellable = messenger->pending_cancellable != nullptr;
  const int send_count = messenger->send_count;
  host.reset();
  DrainMainContext();
  const size_t outstanding_after_teardown =
      NativeSelectableTextMenuHost::
          OutstandingActionCompletionCountForTesting();

  EXPECT_EQ(std::make_tuple(received_cancellable, send_count,
                            outstanding_after_teardown, messenger_finalized),
            std::make_tuple(true, 1, 0u, true));
  if (!messenger_finalized) {
    g_object_weak_unref(G_OBJECT(messenger), MarkObjectFinalized,
                        &messenger_finalized);
  }
}

TEST(NativeSelectableTextMenuHostTest,
     WhenADismissalNeverRepliesItShouldCancelAndReleaseMessengerOnTeardown) {
  if (!EnsureGtk()) {
    GTEST_SKIP() << "GTK requires a display";
  }
  bool messenger_finalized = false;
  NoReplyBinaryMessenger *messenger = MakeNoReplyBinaryMessenger();
  g_object_weak_ref(G_OBJECT(messenger), MarkObjectFinalized,
                    &messenger_finalized);
  auto host = std::make_unique<TestNativeSelectableTextMenuHost>(
      FL_BINARY_MESSENGER(messenger));
  g_object_unref(messenger);
  g_autoptr(OhMyFlutterNativeSelectableTextMenuRequestMessage) request =
      MakeRequest(7, 42);

  ASSERT_TRUE(host->HandleShow(request));
  host->PresentNow();
  const bool received_cancellable = messenger->pending_cancellable != nullptr;
  const int send_count = messenger->send_count;
  host.reset();
  DrainMainContext();

  EXPECT_EQ(std::make_tuple(received_cancellable, send_count,
                            messenger_finalized),
            std::make_tuple(true, 1, true));
  if (!messenger_finalized) {
    g_object_weak_unref(G_OBJECT(messenger), MarkObjectFinalized,
                        &messenger_finalized);
  }
}

TEST(NativeSelectableTextMenuHostTest,
     WhenAnActionRepliesAfterTeardownItShouldIgnoreTheLateCompletion) {
  if (!EnsureGtk()) {
    GTEST_SKIP() << "GTK requires a display";
  }
  NoReplyBinaryMessenger *messenger = MakeNoReplyBinaryMessenger();
  messenger->completes_on_cancellation = false;
  auto host = std::make_unique<TestNativeSelectableTextMenuHost>(
      FL_BINARY_MESSENGER(messenger));
  host->activate_first_item = true;
  g_autoptr(OhMyFlutterNativeSelectableTextMenuRequestMessage) request =
      MakeRequest(7, 42);
  ASSERT_EQ(
      NativeSelectableTextMenuHost::
          OutstandingActionCompletionCountForTesting(),
      0u);

  ASSERT_TRUE(host->HandleShow(request));
  host->PresentNow();
  const size_t outstanding_before_teardown =
      NativeSelectableTextMenuHost::
          OutstandingActionCompletionCountForTesting();

  host.reset();

  const size_t outstanding_after_teardown =
      NativeSelectableTextMenuHost::
          OutstandingActionCompletionCountForTesting();
  CompletePendingMessage(messenger);
  DrainMainContext();
  const size_t outstanding_after_late_reply =
      NativeSelectableTextMenuHost::
          OutstandingActionCompletionCountForTesting();

  EXPECT_EQ(
      std::make_tuple(outstanding_before_teardown,
                      outstanding_after_teardown, messenger->send_count,
                      outstanding_after_late_reply),
      std::make_tuple(1u, 0u, 1, 0u));
  g_object_unref(messenger);
}

TEST(NativeSelectableTextMenuHostTest,
     WhenAnActionRepliesItShouldSendDismissalAndReleaseCompletionState) {
  if (!EnsureGtk()) {
    GTEST_SKIP() << "GTK requires a display";
  }
  NoReplyBinaryMessenger *messenger = MakeNoReplyBinaryMessenger();
  auto host = std::make_unique<TestNativeSelectableTextMenuHost>(
      FL_BINARY_MESSENGER(messenger));
  host->activate_first_item = true;
  g_autoptr(OhMyFlutterNativeSelectableTextMenuRequestMessage) request =
      MakeRequest(7, 42);

  ASSERT_TRUE(host->HandleShow(request));
  host->PresentNow();
  CompletePendingMessage(messenger);
  DrainMainContext();
  const size_t outstanding_after_action =
      NativeSelectableTextMenuHost::
          OutstandingActionCompletionCountForTesting();
  const int sends_after_action = messenger->send_count;
  CompletePendingMessage(messenger);
  DrainMainContext();
  host.reset();

  EXPECT_EQ(std::make_tuple(outstanding_after_action, sends_after_action,
                            messenger->send_count),
            std::make_tuple(0u, 2, 2));
  g_object_unref(messenger);
}

TEST(NativeSelectableTextMenuHostTest,
     WhenTheNativeHostIsUnavailableItShouldRejectShow) {
  NativeSelectableTextMenuHost host(nullptr, nullptr, nullptr);
  g_autoptr(OhMyFlutterNativeSelectableTextMenuRequestMessage) request =
      MakeRequest(1, 2);

  const bool accepted = host.HandleShow(request);

  EXPECT_FALSE(accepted);
}

TEST(NativeSelectableTextMenuHostTest,
     WhenShowIsAcceptedItShouldScheduleOnePresentation) {
  if (!EnsureGtk()) {
    GTEST_SKIP() << "GTK requires a display";
  }
  TestNativeSelectableTextMenuHost host(nullptr, nullptr);
  g_autoptr(OhMyFlutterNativeSelectableTextMenuRequestMessage) request =
      MakeRequest(1, 2);

  host.HandleShow(request);

  EXPECT_EQ(host.schedule_count, 1);
}

TEST(NativeSelectableTextMenuHostTest,
     WhenPresentationCannotBeScheduledItShouldRejectWithoutDismissal) {
  if (!EnsureGtk()) {
    GTEST_SKIP() << "GTK requires a display";
  }
  int dismissal_count = 0;
  TestNativeSelectableTextMenuHost host(
      nullptr, [&dismissal_count](int64_t, bool) { ++dismissal_count; });
  host.schedule_succeeds = false;
  g_autoptr(OhMyFlutterNativeSelectableTextMenuRequestMessage) request =
      MakeRequest(1, 2);

  const bool accepted = host.HandleShow(request);

  EXPECT_EQ(std::make_pair(accepted, dismissal_count),
            std::make_pair(false, 0));
}

TEST(NativeSelectableTextMenuHostTest,
     WhenALabelContainsOnlyWhitespaceItShouldRejectWithoutDismissal) {
  if (!EnsureGtk()) {
    GTEST_SKIP() << "GTK requires a display";
  }
  int dismissal_count = 0;
  TestNativeSelectableTextMenuHost host(
      nullptr, [&dismissal_count](int64_t, bool) { ++dismissal_count; });
  g_autoptr(OhMyFlutterNativeSelectableTextMenuRequestMessage) request =
      MakeRequest(1, 2, 3.25, " \t\r\n");

  const bool accepted = host.HandleShow(request);

  EXPECT_EQ(std::make_pair(accepted, dismissal_count),
            std::make_pair(false, 0));
}

TEST(NativeSelectableTextMenuHostTest,
     WhenGeometryIsNotFiniteItShouldRejectShow) {
  TestNativeSelectableTextMenuHost host(nullptr, nullptr);
  g_autoptr(OhMyFlutterNativeSelectableTextMenuRequestMessage) request =
      MakeRequest(1, 2, std::numeric_limits<double>::quiet_NaN());

  const bool accepted = host.HandleShow(request);

  EXPECT_FALSE(accepted);
}

TEST(NativeSelectableTextMenuHostTest,
     WhenAnActionIsChosenItShouldDeliverActionBeforeDismissal) {
  if (!EnsureGtk()) {
    GTEST_SKIP() << "GTK requires a display";
  }
  std::vector<std::string> events;
  std::function<void()> complete_action;
  TestNativeSelectableTextMenuHost host(
      [&events, &complete_action](int64_t session, int64_t action,
                                  std::function<void()> on_completed) {
        events.push_back("action:" + std::to_string(session) + ":" +
                         std::to_string(action));
        complete_action = std::move(on_completed);
      },
      [&events](int64_t session, bool action_invoked) {
        events.push_back("dismissed:" + std::to_string(session) + ":" +
                         (action_invoked ? "true" : "false"));
      });
  host.activate_first_item = true;
  g_autoptr(OhMyFlutterNativeSelectableTextMenuRequestMessage) request =
      MakeRequest(7, 42);

  host.HandleShow(request);
  host.PresentNow();
  const size_t event_count_before_action_completed = events.size();
  complete_action();

  EXPECT_EQ(std::make_pair(event_count_before_action_completed, events),
            std::make_pair(size_t{1}, std::vector<std::string>{
                                          "action:7:42", "dismissed:7:true"}));
}

TEST(NativeSelectableTextMenuHostTest,
     WhenTheHostIsDestroyedItShouldSuppressThePendingDismissal) {
  if (!EnsureGtk()) {
    GTEST_SKIP() << "GTK requires a display";
  }
  std::function<void()> complete_action;
  int dismissal_count = 0;
  {
    TestNativeSelectableTextMenuHost host(
        [&complete_action](int64_t, int64_t,
                           std::function<void()> on_completed) {
          complete_action = std::move(on_completed);
        },
        [&dismissal_count](int64_t, bool) { ++dismissal_count; });
    host.activate_first_item = true;
    g_autoptr(OhMyFlutterNativeSelectableTextMenuRequestMessage) request =
        MakeRequest(7, 42);
    host.HandleShow(request);
    host.PresentNow();
  }

  complete_action();

  EXPECT_EQ(dismissal_count, 0);
}

TEST(NativeSelectableTextMenuHostTest,
     WhenTheMenuClosesWithoutAnActionItShouldReportOutsideDismissal) {
  if (!EnsureGtk()) {
    GTEST_SKIP() << "GTK requires a display";
  }
  std::vector<std::pair<int64_t, bool>> dismissals;
  TestNativeSelectableTextMenuHost host(
      nullptr, [&dismissals](int64_t session, bool action_invoked) {
        dismissals.emplace_back(session, action_invoked);
      });
  g_autoptr(OhMyFlutterNativeSelectableTextMenuRequestMessage) request =
      MakeRequest(7, 42);

  host.HandleShow(request);
  host.PresentNow();

  EXPECT_EQ(dismissals, (std::vector<std::pair<int64_t, bool>>{{7, false}}));
}

TEST(NativeSelectableTextMenuHostTest,
     WhenTheHostDetachesBeforePresentationItShouldCloseTheSession) {
  if (!EnsureGtk()) {
    GTEST_SKIP() << "GTK requires a display";
  }
  std::vector<std::pair<int64_t, bool>> dismissals;
  TestNativeSelectableTextMenuHost host(
      nullptr, [&dismissals](int64_t session, bool action_invoked) {
        dismissals.emplace_back(session, action_invoked);
      });
  g_autoptr(OhMyFlutterNativeSelectableTextMenuRequestMessage) request =
      MakeRequest(7, 42);
  host.HandleShow(request);
  host.native_window_available = false;

  host.PresentNow();

  EXPECT_EQ(dismissals, (std::vector<std::pair<int64_t, bool>>{{7, false}}));
}

TEST(NativeSelectableTextMenuHostTest,
     WhenUpdateUsesAStaleSessionItShouldRejectTheRequest) {
  if (!EnsureGtk()) {
    GTEST_SKIP() << "GTK requires a display";
  }
  TestNativeSelectableTextMenuHost host(nullptr, nullptr);
  g_autoptr(OhMyFlutterNativeSelectableTextMenuRequestMessage) shown_request =
      MakeRequest(7, 42);
  g_autoptr(OhMyFlutterNativeSelectableTextMenuRequestMessage) stale_request =
      MakeRequest(8, 99);
  host.HandleShow(shown_request);

  const bool accepted = host.HandleUpdate(stale_request);

  EXPECT_FALSE(accepted);
}

TEST(NativeSelectableTextMenuHostTest,
     WhenCurrentUpdateIsRejectedItShouldSilentlyRemoveTheOldMenu) {
  if (!EnsureGtk()) {
    GTEST_SKIP() << "GTK requires a display";
  }
  int dismissal_count = 0;
  TestNativeSelectableTextMenuHost host(
      nullptr, [&dismissal_count](int64_t, bool) { ++dismissal_count; });
  g_autoptr(OhMyFlutterNativeSelectableTextMenuRequestMessage) shown_request =
      MakeRequest(7, 42);
  g_autoptr(OhMyFlutterNativeSelectableTextMenuRequestMessage) update_request =
      MakeRequest(7, 99);
  host.HandleShow(shown_request);
  host.host_available = false;

  const bool accepted = host.HandleUpdate(update_request);
  host.host_available = true;
  host.PresentNow();

  EXPECT_EQ(std::make_tuple(accepted, host.presentation_count, dismissal_count),
            std::make_tuple(false, 0, 0));
}

TEST(NativeSelectableTextMenuHostTest,
     WhenActiveUpdateCannotBeScheduledItShouldRejectWithoutDismissal) {
  if (!EnsureGtk()) {
    GTEST_SKIP() << "GTK requires a display";
  }
  int dismissal_count = 0;
  bool update_accepted = true;
  TestNativeSelectableTextMenuHost host(
      nullptr, [&dismissal_count](int64_t, bool) { ++dismissal_count; });
  g_autoptr(OhMyFlutterNativeSelectableTextMenuRequestMessage) shown_request =
      MakeRequest(7, 42);
  g_autoptr(OhMyFlutterNativeSelectableTextMenuRequestMessage) update_request =
      MakeRequest(7, 99);
  host.during_presentation = [&host, &update_accepted, update_request] {
    host.schedule_succeeds = false;
    update_accepted = host.HandleUpdate(update_request);
  };

  host.HandleShow(shown_request);
  host.PresentNow();

  EXPECT_EQ(std::make_pair(update_accepted, dismissal_count),
            std::make_pair(false, 0));
}

TEST(NativeSelectableTextMenuHostTest,
     WhenUpdateUsesTheCurrentSessionItShouldReplaceTheNativeActions) {
  if (!EnsureGtk()) {
    GTEST_SKIP() << "GTK requires a display";
  }
  std::vector<int64_t> actions;
  TestNativeSelectableTextMenuHost host(
      [&actions](int64_t, int64_t action, std::function<void()> on_completed) {
        actions.push_back(action);
        on_completed();
      },
      nullptr);
  host.activate_first_item = true;
  g_autoptr(OhMyFlutterNativeSelectableTextMenuRequestMessage) shown_request =
      MakeRequest(7, 42);
  g_autoptr(OhMyFlutterNativeSelectableTextMenuRequestMessage) update_request =
      MakeRequest(7, 99);
  host.HandleShow(shown_request);

  const bool accepted = host.HandleUpdate(update_request);
  host.PresentNow();

  EXPECT_EQ(std::make_pair(accepted, actions),
            std::make_pair(true, std::vector<int64_t>{99}));
}

TEST(NativeSelectableTextMenuHostTest,
     WhenAPendingUpdateIsIdenticalItShouldKeepTheExistingMenu) {
  if (!EnsureGtk()) {
    GTEST_SKIP() << "GTK requires a display";
  }
  TestNativeSelectableTextMenuHost host(nullptr, nullptr);
  g_autoptr(OhMyFlutterNativeSelectableTextMenuRequestMessage) shown_request =
      MakeRequest(7, 42);
  g_autoptr(OhMyFlutterNativeSelectableTextMenuRequestMessage) update_request =
      MakeRequest(7, 42);

  host.HandleShow(shown_request);
  const bool update_accepted = host.HandleUpdate(update_request);

  EXPECT_EQ(std::make_tuple(update_accepted, host.destroyed_menu_count,
                            host.schedule_count),
            std::make_tuple(true, 0, 1));
}

TEST(NativeSelectableTextMenuHostTest,
     WhenOnlyPendingGeometryChangesItShouldReuseTheExistingMenu) {
  if (!EnsureGtk()) {
    GTEST_SKIP() << "GTK requires a display";
  }
  TestNativeSelectableTextMenuHost host(nullptr, nullptr);
  g_autoptr(OhMyFlutterNativeSelectableTextMenuRequestMessage) shown_request =
      MakeRequest(7, 42);
  g_autoptr(OhMyFlutterNativeSelectableTextMenuRequestMessage) update_request =
      MakeRequest(7, 42, 25.0);

  host.HandleShow(shown_request);
  const bool update_accepted = host.HandleUpdate(update_request);
  const int destroyed_menu_count = host.destroyed_menu_count;
  host.PresentNow();

  EXPECT_EQ(std::make_tuple(update_accepted, destroyed_menu_count,
                            host.presentation_count, host.presented_anchor.x),
            std::make_tuple(true, 0, 1, 25));
}

TEST(NativeSelectableTextMenuHostTest,
     WhenCompactPendingGeometryChangesItShouldReuseTheExistingMenu) {
  if (!EnsureGtk()) {
    GTEST_SKIP() << "GTK requires a display";
  }
  TestNativeSelectableTextMenuHost host(nullptr, nullptr);
  g_autoptr(OhMyFlutterNativeSelectableTextMenuRequestMessage) request =
      MakeRequest(7, 42);
  host.HandleShow(request);
  const std::vector<double> geometry = MakeGeometry(1, 2, 8, 9, 25);

  const bool update_accepted =
      host.HandleUpdateGeometry(7, geometry.data(), geometry.size());
  const int destroyed_menu_count = host.destroyed_menu_count;
  host.PresentNow();

  EXPECT_EQ(std::make_tuple(update_accepted, destroyed_menu_count,
                            host.presentation_count, host.presented_anchor.x),
            std::make_tuple(true, 0, 1, 25));
}

TEST(NativeSelectableTextMenuHostTest,
     WhenAFullUpdateFollowsCompactGeometryItShouldRestoreRequestedPlacement) {
  if (!EnsureGtk()) {
    GTEST_SKIP() << "GTK requires a display";
  }
  TestNativeSelectableTextMenuHost host(nullptr, nullptr);
  g_autoptr(OhMyFlutterNativeSelectableTextMenuRequestMessage) shown_request =
      MakeRequest(7, 42);
  g_autoptr(OhMyFlutterNativeSelectableTextMenuRequestMessage) full_update =
      MakeRequest(7, 42);
  const std::vector<double> geometry = MakeGeometry(1, 2, 8, 9, 25);
  host.HandleShow(shown_request);
  host.HandleUpdateGeometry(7, geometry.data(), geometry.size());

  const bool update_accepted = host.HandleUpdate(full_update);
  host.PresentNow();

  EXPECT_EQ(std::make_tuple(update_accepted, host.presentation_count,
                            host.presented_anchor.x),
            std::make_tuple(true, 1, 3));
}

TEST(NativeSelectableTextMenuHostTest,
     WhenAnActiveUpdateIsIdenticalItShouldKeepTheExistingMenu) {
  if (!EnsureGtk()) {
    GTEST_SKIP() << "GTK requires a display";
  }
  TestNativeSelectableTextMenuHost host(nullptr, nullptr);
  g_autoptr(OhMyFlutterNativeSelectableTextMenuRequestMessage) shown_request =
      MakeRequest(7, 42);
  g_autoptr(OhMyFlutterNativeSelectableTextMenuRequestMessage) update_request =
      MakeRequest(7, 42);
  bool update_accepted = false;
  host.during_presentation = [&host, &update_accepted, update_request] {
    update_accepted = host.HandleUpdate(update_request);
  };

  host.HandleShow(shown_request);
  host.PresentNow();
  host.PresentNow();

  EXPECT_EQ(std::make_tuple(update_accepted, host.presentation_count,
                            host.schedule_count),
            std::make_tuple(true, 1, 1));
}

TEST(NativeSelectableTextMenuHostTest,
     WhenOnlyActiveGeometryChangesItShouldReuseTheExistingMenuAndActions) {
  if (!EnsureGtk()) {
    GTEST_SKIP() << "GTK requires a display";
  }
  std::vector<int64_t> actions;
  TestNativeSelectableTextMenuHost host(
      [&actions](int64_t, int64_t action, std::function<void()> on_completed) {
        actions.push_back(action);
        on_completed();
      },
      nullptr);
  host.activate_first_item = true;
  g_autoptr(OhMyFlutterNativeSelectableTextMenuRequestMessage) shown_request =
      MakeRequest(7, 42);
  g_autoptr(OhMyFlutterNativeSelectableTextMenuRequestMessage) update_request =
      MakeRequest(7, 42, 25.0);
  bool update_accepted = false;
  host.during_presentation = [&host, &update_accepted, update_request] {
    update_accepted = host.HandleUpdate(update_request);
  };

  host.HandleShow(shown_request);
  host.PresentNow();
  host.PresentNow();

  EXPECT_EQ(std::make_tuple(update_accepted, host.presentation_count,
                            host.reused_first_menu, actions),
            std::make_tuple(true, 2, true, std::vector<int64_t>{42}));
}

TEST(NativeSelectableTextMenuHostTest,
     WhenCompactActiveGeometryChangesItShouldReuseTheExistingMenuAndActions) {
  if (!EnsureGtk()) {
    GTEST_SKIP() << "GTK requires a display";
  }
  std::vector<int64_t> actions;
  TestNativeSelectableTextMenuHost host(
      [&actions](int64_t, int64_t action, std::function<void()> on_completed) {
        actions.push_back(action);
        on_completed();
      },
      nullptr);
  host.activate_first_item = true;
  g_autoptr(OhMyFlutterNativeSelectableTextMenuRequestMessage) request =
      MakeRequest(7, 42);
  const std::vector<double> geometry = MakeGeometry(1, 2, 8, 9, 25);
  bool update_accepted = false;
  host.during_presentation = [&host, &update_accepted, &geometry] {
    update_accepted =
        host.HandleUpdateGeometry(7, geometry.data(), geometry.size());
  };

  host.HandleShow(request);
  host.PresentNow();
  host.PresentNow();

  EXPECT_EQ(std::make_tuple(update_accepted, host.presentation_count,
                            host.reused_first_menu, actions),
            std::make_tuple(true, 2, true, std::vector<int64_t>{42}));
}

TEST(NativeSelectableTextMenuHostTest,
     WhenCompactActiveGeometryIsUnchangedItShouldPerformNoMenuWork) {
  if (!EnsureGtk()) {
    GTEST_SKIP() << "GTK requires a display";
  }
  TestNativeSelectableTextMenuHost host(nullptr, nullptr);
  g_autoptr(OhMyFlutterNativeSelectableTextMenuRequestMessage) request =
      MakeRequest(7, 42);
  const std::vector<double> geometry = MakeGeometry();
  bool update_accepted = false;
  host.during_presentation = [&host, &update_accepted, &geometry] {
    update_accepted =
        host.HandleUpdateGeometry(7, geometry.data(), geometry.size());
  };

  host.HandleShow(request);
  host.PresentNow();
  host.PresentNow();

  EXPECT_EQ(std::make_tuple(update_accepted, host.presentation_count,
                            host.schedule_count),
            std::make_tuple(true, 1, 1));
}

TEST(NativeSelectableTextMenuHostTest,
     WhenCompactGeometryUsesAStaleSessionItShouldRejectTheUpdate) {
  if (!EnsureGtk()) {
    GTEST_SKIP() << "GTK requires a display";
  }
  TestNativeSelectableTextMenuHost host(nullptr, nullptr);
  g_autoptr(OhMyFlutterNativeSelectableTextMenuRequestMessage) request =
      MakeRequest(7, 42);
  const std::vector<double> geometry = MakeGeometry();
  host.HandleShow(request);

  const bool accepted =
      host.HandleUpdateGeometry(8, geometry.data(), geometry.size());

  EXPECT_FALSE(accepted);
}

TEST(NativeSelectableTextMenuHostTest,
     WhenCompactGeometryHasTheWrongLengthItShouldRejectTheUpdate) {
  if (!EnsureGtk()) {
    GTEST_SKIP() << "GTK requires a display";
  }
  TestNativeSelectableTextMenuHost host(nullptr, nullptr);
  g_autoptr(OhMyFlutterNativeSelectableTextMenuRequestMessage) request =
      MakeRequest(7, 42);
  const std::vector<double> geometry = {1, 2, 8};
  host.HandleShow(request);

  const bool accepted =
      host.HandleUpdateGeometry(7, geometry.data(), geometry.size());

  EXPECT_FALSE(accepted);
}

TEST(NativeSelectableTextMenuHostTest,
     WhenCompactGeometryIsNotFiniteItShouldRejectTheUpdate) {
  if (!EnsureGtk()) {
    GTEST_SKIP() << "GTK requires a display";
  }
  TestNativeSelectableTextMenuHost host(nullptr, nullptr);
  g_autoptr(OhMyFlutterNativeSelectableTextMenuRequestMessage) request =
      MakeRequest(7, 42);
  const std::vector<double> geometry = MakeGeometry(
      1, 2, 8, 9, std::numeric_limits<double>::quiet_NaN());
  host.HandleShow(request);

  const bool accepted =
      host.HandleUpdateGeometry(7, geometry.data(), geometry.size());

  EXPECT_FALSE(accepted);
}

TEST(NativeSelectableTextMenuHostTest,
     WhenCompactGeometryIsInvertedItShouldRejectTheUpdate) {
  if (!EnsureGtk()) {
    GTEST_SKIP() << "GTK requires a display";
  }
  TestNativeSelectableTextMenuHost host(nullptr, nullptr);
  g_autoptr(OhMyFlutterNativeSelectableTextMenuRequestMessage) request =
      MakeRequest(7, 42);
  const std::vector<double> geometry = MakeGeometry(9, 2, 8, 9);
  host.HandleShow(request);

  const bool accepted =
      host.HandleUpdateGeometry(7, geometry.data(), geometry.size());

  EXPECT_FALSE(accepted);
}

TEST(NativeSelectableTextMenuHostTest,
     WhenTheHostIsUnavailableItShouldRejectCompactGeometry) {
  if (!EnsureGtk()) {
    GTEST_SKIP() << "GTK requires a display";
  }
  TestNativeSelectableTextMenuHost host(nullptr, nullptr);
  g_autoptr(OhMyFlutterNativeSelectableTextMenuRequestMessage) request =
      MakeRequest(7, 42);
  const std::vector<double> geometry = MakeGeometry(1, 2, 8, 9, 25);
  host.HandleShow(request);
  host.host_available = false;

  const bool accepted =
      host.HandleUpdateGeometry(7, geometry.data(), geometry.size());

  EXPECT_FALSE(accepted);
}

TEST(NativeSelectableTextMenuHostTest,
     WhenActiveActionsChangeItShouldBuildANewMenuAndUseNewActions) {
  if (!EnsureGtk()) {
    GTEST_SKIP() << "GTK requires a display";
  }
  std::vector<int64_t> actions;
  TestNativeSelectableTextMenuHost host(
      [&actions](int64_t, int64_t action, std::function<void()> on_completed) {
        actions.push_back(action);
        on_completed();
      },
      nullptr);
  host.activate_first_item = true;
  g_autoptr(OhMyFlutterNativeSelectableTextMenuRequestMessage) shown_request =
      MakeRequest(7, 42);
  g_autoptr(OhMyFlutterNativeSelectableTextMenuRequestMessage) update_request =
      MakeRequest(7, 99, 25.0);
  bool update_accepted = false;
  host.during_presentation = [&host, &update_accepted, update_request] {
    update_accepted = host.HandleUpdate(update_request);
  };

  host.HandleShow(shown_request);
  host.PresentNow();
  host.PresentNow();

  EXPECT_EQ(std::make_tuple(update_accepted, host.presentation_count,
                            host.reused_first_menu, actions),
            std::make_tuple(true, 2, false, std::vector<int64_t>{99}));
}

TEST(NativeSelectableTextMenuHostTest,
     WhenTheCurrentPendingMenuIsHiddenItShouldNotPresentOrDismiss) {
  if (!EnsureGtk()) {
    GTEST_SKIP() << "GTK requires a display";
  }
  int dismissal_count = 0;
  TestNativeSelectableTextMenuHost host(
      nullptr, [&dismissal_count](int64_t, bool) { ++dismissal_count; });
  g_autoptr(OhMyFlutterNativeSelectableTextMenuRequestMessage) request =
      MakeRequest(7, 42);
  host.HandleShow(request);

  host.HandleHide(7);
  host.PresentNow();

  EXPECT_EQ(std::make_pair(host.presentation_count, dismissal_count),
            std::make_pair(0, 0));
}

TEST(NativeSelectableTextMenuHostTest,
     WhenShowingTheMenuItShouldUseThePrimaryDesktopAnchor) {
  if (!EnsureGtk()) {
    GTEST_SKIP() << "GTK requires a display";
  }
  TestNativeSelectableTextMenuHost host(nullptr, nullptr);
  g_autoptr(OhMyFlutterNativeSelectableTextMenuRequestMessage) request =
      MakeRequest(7, 42);
  host.HandleShow(request);

  host.PresentNow();

  const std::vector<int> placement = {
      host.presented_anchor.x,
      host.presented_anchor.y,
      host.presented_anchor.width,
      host.presented_anchor.height,
  };
  EXPECT_EQ(placement, (std::vector<int>{3, 5, 1, 1}));
}

} // namespace test
} // namespace oh_my_flutter
