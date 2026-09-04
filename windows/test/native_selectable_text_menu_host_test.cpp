#include <gtest/gtest.h>
#include <windows.h>

#include <cstdint>
#include <limits>
#include <string>
#include <tuple>
#include <utility>
#include <vector>

#include "native_selectable_text_menu_host.h"

namespace oh_my_flutter {
namespace test {

namespace {

constexpr UINT kPresentationMessage = WM_APP + 417;

NativeSelectableTextMenuRequestMessage MakeRequest(int64_t session_identifier,
                                                   int64_t action_identifier,
                                                   double anchor_dx = 3.25,
                                                   std::string label = "Copy") {
  flutter::EncodableList items;
  items.emplace_back(flutter::CustomEncodableValue(
      NativeSelectableTextMenuItemMessage(action_identifier, label)));
  return NativeSelectableTextMenuRequestMessage(
      session_identifier,
      NativeSelectableTextRectangleMessage(1.0, 2.0, 8.0, 9.0),
      NativeSelectableTextPointMessage(anchor_dx, 4.75), items);
}

std::vector<double> MakeGeometry(double left = 1.0, double top = 2.0,
                                 double right = 8.0, double bottom = 9.0,
                                 double anchor_dx = 3.25,
                                 double anchor_dy = 4.75) {
  return {left, top, right, bottom, anchor_dx, anchor_dy};
}

class TestNativeSelectableTextMenuHost : public NativeSelectableTextMenuHost {
public:
  TestNativeSelectableTextMenuHost(
      std::function<void(int64_t, int64_t, std::function<void()>)> on_action,
      std::function<void(int64_t, bool)> on_dismissed)
      : NativeSelectableTextMenuHost(nullptr, nullptr, kPresentationMessage,
                                     std::move(on_action),
                                     std::move(on_dismissed)) {}

  UINT selected_command = 0;
  int schedule_count = 0;
  int presentation_count = 0;
  POINT presented_anchor = {};
  RECT presented_exclusion = {};
  bool reused_first_menu = false;
  bool host_available = true;
  bool schedule_succeeds = true;
  std::function<void()> during_presentation;

protected:
  bool HasNativeHost() const override { return host_available; }

  bool SchedulePresentation() override {
    ++schedule_count;
    return schedule_succeeds;
  }

  void DismissActiveMenu() override {}

  UINT PresentNativeMenu(HMENU menu, const POINT &anchor,
                         const RECT &exclusion_rectangle) override {
    ++presentation_count;
    presented_anchor = anchor;
    presented_exclusion = exclusion_rectangle;
    MENUINFO menu_information = {};
    menu_information.cbSize = sizeof(menu_information);
    menu_information.fMask = MIM_MENUDATA;
    if (presentation_count == 1) {
      menu_information.dwMenuData = reinterpret_cast<ULONG_PTR>(this);
      SetMenuInfo(menu, &menu_information);
    } else if (GetMenuInfo(menu, &menu_information) != FALSE) {
      reused_first_menu =
          menu_information.dwMenuData == reinterpret_cast<ULONG_PTR>(this);
    }
    if (during_presentation) {
      auto callback = std::move(during_presentation);
      callback();
    }
    return selected_command;
  }

  double DevicePixelRatio() const override { return 2.0; }

  bool ConvertViewPointToScreen(POINT *point) const override {
    point->x += 100;
    point->y += 200;
    return true;
  }
};

} // namespace

TEST(NativeSelectableTextMenuHostTest,
     WhenTheNativeHostIsUnavailableItShouldRejectShow) {
  NativeSelectableTextMenuHost host(nullptr, nullptr, 0, nullptr, nullptr);

  const auto result = host.Show(MakeRequest(1, 2));

  EXPECT_FALSE(result.value());
}

TEST(NativeSelectableTextMenuHostTest,
     WhenShowIsAcceptedItShouldScheduleOnePresentation) {
  TestNativeSelectableTextMenuHost host(nullptr, nullptr);

  const auto result = host.Show(MakeRequest(1, 2));

  EXPECT_EQ(std::make_pair(result.value(), host.schedule_count),
            std::make_pair(true, 1));
}

TEST(NativeSelectableTextMenuHostTest,
     WhenPresentationCannotBeScheduledItShouldRejectWithoutDismissal) {
  int dismissal_count = 0;
  TestNativeSelectableTextMenuHost host(
      nullptr, [&dismissal_count](int64_t, bool) { ++dismissal_count; });
  host.schedule_succeeds = false;

  const auto result = host.Show(MakeRequest(1, 2));

  EXPECT_EQ(std::make_pair(result.value(), dismissal_count),
            std::make_pair(false, 0));
}

TEST(NativeSelectableTextMenuHostTest,
     WhenALabelContainsOnlyWhitespaceItShouldRejectWithoutDismissal) {
  int dismissal_count = 0;
  TestNativeSelectableTextMenuHost host(
      nullptr, [&dismissal_count](int64_t, bool) { ++dismissal_count; });

  const auto result = host.Show(MakeRequest(1, 2, 3.25, " \t\r\n"));

  EXPECT_EQ(std::make_pair(result.value(), dismissal_count),
            std::make_pair(false, 0));
}

TEST(NativeSelectableTextMenuHostTest,
     WhenGeometryIsNotFiniteItShouldRejectShow) {
  TestNativeSelectableTextMenuHost host(nullptr, nullptr);

  const auto result =
      host.Show(MakeRequest(1, 2, std::numeric_limits<double>::quiet_NaN()));

  EXPECT_FALSE(result.value());
}

TEST(NativeSelectableTextMenuHostTest,
     WhenAnActionIsChosenItShouldDeliverActionBeforeDismissal) {
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
  host.selected_command = 1;

  host.Show(MakeRequest(7, 42));
  host.HandleWindowMessage(kPresentationMessage);
  const size_t event_count_before_action_completed = events.size();
  complete_action();

  EXPECT_EQ(std::make_pair(event_count_before_action_completed, events),
            std::make_pair(size_t{1}, std::vector<std::string>{
                                          "action:7:42", "dismissed:7:true"}));
}

TEST(NativeSelectableTextMenuHostTest,
     WhenTheHostIsDestroyedItShouldSuppressThePendingDismissal) {
  std::function<void()> complete_action;
  int dismissal_count = 0;
  {
    TestNativeSelectableTextMenuHost host(
        [&complete_action](int64_t, int64_t,
                           std::function<void()> on_completed) {
          complete_action = std::move(on_completed);
        },
        [&dismissal_count](int64_t, bool) { ++dismissal_count; });
    host.selected_command = 1;
    host.Show(MakeRequest(7, 42));
    host.HandleWindowMessage(kPresentationMessage);
  }

  complete_action();

  EXPECT_EQ(dismissal_count, 0);
}

TEST(NativeSelectableTextMenuHostTest,
     WhenTheMenuClosesWithoutAnActionItShouldReportOutsideDismissal) {
  std::vector<std::pair<int64_t, bool>> dismissals;
  TestNativeSelectableTextMenuHost host(
      nullptr, [&dismissals](int64_t session, bool action_invoked) {
        dismissals.emplace_back(session, action_invoked);
      });

  host.Show(MakeRequest(7, 42));
  host.HandleWindowMessage(kPresentationMessage);

  EXPECT_EQ(dismissals, (std::vector<std::pair<int64_t, bool>>{{7, false}}));
}

TEST(NativeSelectableTextMenuHostTest,
     WhenTheHostDetachesBeforePresentationItShouldCloseTheSession) {
  std::vector<std::pair<int64_t, bool>> dismissals;
  TestNativeSelectableTextMenuHost host(
      nullptr, [&dismissals](int64_t session, bool action_invoked) {
        dismissals.emplace_back(session, action_invoked);
      });
  host.Show(MakeRequest(7, 42));
  host.host_available = false;

  host.HandleWindowMessage(kPresentationMessage);

  EXPECT_EQ(dismissals, (std::vector<std::pair<int64_t, bool>>{{7, false}}));
}

TEST(NativeSelectableTextMenuHostTest,
     WhenUpdateUsesAStaleSessionItShouldRejectTheRequest) {
  TestNativeSelectableTextMenuHost host(nullptr, nullptr);
  host.Show(MakeRequest(7, 42));

  const auto result = host.Update(MakeRequest(8, 99));

  EXPECT_FALSE(result.value());
}

TEST(NativeSelectableTextMenuHostTest,
     WhenCurrentUpdateIsRejectedItShouldSilentlyRemoveTheOldMenu) {
  int dismissal_count = 0;
  TestNativeSelectableTextMenuHost host(
      nullptr, [&dismissal_count](int64_t, bool) { ++dismissal_count; });
  host.Show(MakeRequest(7, 42));
  host.host_available = false;

  const auto result = host.Update(MakeRequest(7, 99));
  host.host_available = true;
  host.HandleWindowMessage(kPresentationMessage);

  EXPECT_EQ(
      std::make_tuple(result.value(), host.presentation_count, dismissal_count),
      std::make_tuple(false, 0, 0));
}

TEST(NativeSelectableTextMenuHostTest,
     WhenActiveUpdateCannotBeScheduledItShouldRejectWithoutDismissal) {
  int dismissal_count = 0;
  bool update_accepted = true;
  TestNativeSelectableTextMenuHost host(
      nullptr, [&dismissal_count](int64_t, bool) { ++dismissal_count; });
  host.during_presentation = [&host, &update_accepted] {
    host.schedule_succeeds = false;
    update_accepted = host.Update(MakeRequest(7, 99)).value();
  };

  host.Show(MakeRequest(7, 42));
  host.HandleWindowMessage(kPresentationMessage);

  EXPECT_EQ(std::make_pair(update_accepted, dismissal_count),
            std::make_pair(false, 0));
}

TEST(NativeSelectableTextMenuHostTest,
     WhenUpdateUsesTheCurrentSessionItShouldReplaceTheNativeActions) {
  std::vector<int64_t> actions;
  TestNativeSelectableTextMenuHost host(
      [&actions](int64_t, int64_t action, std::function<void()> on_completed) {
        actions.push_back(action);
        on_completed();
      },
      nullptr);
  host.selected_command = 1;
  host.Show(MakeRequest(7, 42));

  const auto result = host.Update(MakeRequest(7, 99));
  host.HandleWindowMessage(kPresentationMessage);

  EXPECT_EQ(std::make_pair(result.value(), actions),
            std::make_pair(true, std::vector<int64_t>{99}));
}

TEST(NativeSelectableTextMenuHostTest,
     WhenAnActiveUpdateIsIdenticalItShouldKeepTheExistingMenu) {
  TestNativeSelectableTextMenuHost host(nullptr, nullptr);
  const NativeSelectableTextMenuRequestMessage shown_request =
      MakeRequest(7, 42);
  const NativeSelectableTextMenuRequestMessage update_request =
      MakeRequest(7, 42);
  bool update_accepted = false;
  host.during_presentation = [&host, &update_accepted, &update_request] {
    update_accepted = host.Update(update_request).value();
  };

  host.Show(shown_request);
  host.HandleWindowMessage(kPresentationMessage);
  host.HandleWindowMessage(kPresentationMessage);

  EXPECT_EQ(std::make_tuple(update_accepted, host.presentation_count,
                            host.schedule_count),
            std::make_tuple(true, 1, 1));
}

TEST(NativeSelectableTextMenuHostTest,
     WhenCompactPendingGeometryChangesItShouldReuseTheExistingMenu) {
  TestNativeSelectableTextMenuHost host(nullptr, nullptr);
  host.Show(MakeRequest(7, 42));

  const auto result = host.UpdateGeometry(7, MakeGeometry(1, 2, 8, 9, 25));
  host.HandleWindowMessage(kPresentationMessage);

  EXPECT_EQ(std::make_tuple(result.value(), host.presentation_count,
                            host.presented_anchor.x),
            std::make_tuple(true, 1, LONG{150}));
}

TEST(NativeSelectableTextMenuHostTest,
     WhenAFullUpdateFollowsCompactGeometryItShouldRestoreRequestedPlacement) {
  TestNativeSelectableTextMenuHost host(nullptr, nullptr);
  host.Show(MakeRequest(7, 42));
  host.UpdateGeometry(7, MakeGeometry(1, 2, 8, 9, 25));

  const auto result = host.Update(MakeRequest(7, 42));
  host.HandleWindowMessage(kPresentationMessage);

  EXPECT_EQ(std::make_tuple(result.value(), host.presentation_count,
                            host.presented_anchor.x),
            std::make_tuple(true, 1, LONG{107}));
}

TEST(NativeSelectableTextMenuHostTest,
     WhenOnlyActiveGeometryChangesItShouldReuseTheExistingMenuAndActions) {
  std::vector<int64_t> actions;
  TestNativeSelectableTextMenuHost host(
      [&actions](int64_t, int64_t action, std::function<void()> on_completed) {
        actions.push_back(action);
        on_completed();
      },
      nullptr);
  host.selected_command = 1;
  const NativeSelectableTextMenuRequestMessage shown_request =
      MakeRequest(7, 42);
  const NativeSelectableTextMenuRequestMessage update_request =
      MakeRequest(7, 42, 25.0);
  bool update_accepted = false;
  host.during_presentation = [&host, &update_accepted, &update_request] {
    update_accepted = host.Update(update_request).value();
  };

  host.Show(shown_request);
  host.HandleWindowMessage(kPresentationMessage);
  host.HandleWindowMessage(kPresentationMessage);

  EXPECT_EQ(std::make_tuple(update_accepted, host.presentation_count,
                            host.reused_first_menu, actions),
            std::make_tuple(true, 2, true, std::vector<int64_t>{42}));
}

TEST(NativeSelectableTextMenuHostTest,
     WhenCompactActiveGeometryChangesItShouldReuseTheExistingMenuAndActions) {
  std::vector<int64_t> actions;
  TestNativeSelectableTextMenuHost host(
      [&actions](int64_t, int64_t action, std::function<void()> on_completed) {
        actions.push_back(action);
        on_completed();
      },
      nullptr);
  host.selected_command = 1;
  bool update_accepted = false;
  host.during_presentation = [&host, &update_accepted] {
    update_accepted =
        host.UpdateGeometry(7, MakeGeometry(1, 2, 8, 9, 25)).value();
  };

  host.Show(MakeRequest(7, 42));
  host.HandleWindowMessage(kPresentationMessage);
  host.HandleWindowMessage(kPresentationMessage);

  EXPECT_EQ(std::make_tuple(update_accepted, host.presentation_count,
                            host.reused_first_menu, actions),
            std::make_tuple(true, 2, true, std::vector<int64_t>{42}));
}

TEST(NativeSelectableTextMenuHostTest,
     WhenCompactActiveGeometryIsUnchangedItShouldPerformNoMenuWork) {
  TestNativeSelectableTextMenuHost host(nullptr, nullptr);
  bool update_accepted = false;
  host.during_presentation = [&host, &update_accepted] {
    update_accepted = host.UpdateGeometry(7, MakeGeometry()).value();
  };

  host.Show(MakeRequest(7, 42));
  host.HandleWindowMessage(kPresentationMessage);
  host.HandleWindowMessage(kPresentationMessage);

  EXPECT_EQ(std::make_tuple(update_accepted, host.presentation_count,
                            host.schedule_count),
            std::make_tuple(true, 1, 1));
}

TEST(NativeSelectableTextMenuHostTest,
     WhenCompactGeometryUsesAStaleSessionItShouldRejectTheUpdate) {
  TestNativeSelectableTextMenuHost host(nullptr, nullptr);
  host.Show(MakeRequest(7, 42));

  const auto result = host.UpdateGeometry(8, MakeGeometry());

  EXPECT_FALSE(result.value());
}

TEST(NativeSelectableTextMenuHostTest,
     WhenCompactGeometryHasTheWrongLengthItShouldRejectTheUpdate) {
  TestNativeSelectableTextMenuHost host(nullptr, nullptr);
  host.Show(MakeRequest(7, 42));

  const auto result = host.UpdateGeometry(7, {1, 2, 8});

  EXPECT_FALSE(result.value());
}

TEST(NativeSelectableTextMenuHostTest,
     WhenCompactGeometryIsNotFiniteItShouldRejectTheUpdate) {
  TestNativeSelectableTextMenuHost host(nullptr, nullptr);
  host.Show(MakeRequest(7, 42));

  const auto result = host.UpdateGeometry(
      7, MakeGeometry(1, 2, 8, 9,
                      std::numeric_limits<double>::quiet_NaN()));

  EXPECT_FALSE(result.value());
}

TEST(NativeSelectableTextMenuHostTest,
     WhenCompactGeometryIsInvertedItShouldRejectTheUpdate) {
  TestNativeSelectableTextMenuHost host(nullptr, nullptr);
  host.Show(MakeRequest(7, 42));

  const auto result = host.UpdateGeometry(7, MakeGeometry(9, 2, 8, 9));

  EXPECT_FALSE(result.value());
}

TEST(NativeSelectableTextMenuHostTest,
     WhenTheHostIsUnavailableItShouldRejectCompactGeometry) {
  TestNativeSelectableTextMenuHost host(nullptr, nullptr);
  host.Show(MakeRequest(7, 42));
  host.host_available = false;

  const auto result = host.UpdateGeometry(7, MakeGeometry(1, 2, 8, 9, 25));

  EXPECT_FALSE(result.value());
}

TEST(NativeSelectableTextMenuHostTest,
     WhenActiveActionsChangeItShouldBuildANewMenuAndUseNewActions) {
  std::vector<int64_t> actions;
  TestNativeSelectableTextMenuHost host(
      [&actions](int64_t, int64_t action, std::function<void()> on_completed) {
        actions.push_back(action);
        on_completed();
      },
      nullptr);
  host.selected_command = 1;
  const NativeSelectableTextMenuRequestMessage shown_request =
      MakeRequest(7, 42);
  const NativeSelectableTextMenuRequestMessage update_request =
      MakeRequest(7, 99, 25.0);
  bool update_accepted = false;
  host.during_presentation = [&host, &update_accepted, &update_request] {
    update_accepted = host.Update(update_request).value();
  };

  host.Show(shown_request);
  host.HandleWindowMessage(kPresentationMessage);
  host.HandleWindowMessage(kPresentationMessage);

  EXPECT_EQ(std::make_tuple(update_accepted, host.presentation_count,
                            host.reused_first_menu, actions),
            std::make_tuple(true, 2, false, std::vector<int64_t>{99}));
}

TEST(NativeSelectableTextMenuHostTest,
     WhenTheCurrentPendingMenuIsHiddenItShouldNotPresentOrDismiss) {
  int dismissal_count = 0;
  TestNativeSelectableTextMenuHost host(
      nullptr, [&dismissal_count](int64_t, bool) { ++dismissal_count; });
  host.Show(MakeRequest(7, 42));

  host.Hide(7);
  host.HandleWindowMessage(kPresentationMessage);

  EXPECT_EQ(std::make_pair(host.presentation_count, dismissal_count),
            std::make_pair(0, 0));
}

TEST(NativeSelectableTextMenuHostTest,
     WhenShowingTheMenuItShouldScaleAndTranslateItsPlacement) {
  TestNativeSelectableTextMenuHost host(nullptr, nullptr);
  host.Show(MakeRequest(7, 42));

  host.HandleWindowMessage(kPresentationMessage);

  const std::vector<LONG> placement = {
      host.presented_anchor.x,        host.presented_anchor.y,
      host.presented_exclusion.left,  host.presented_exclusion.top,
      host.presented_exclusion.right, host.presented_exclusion.bottom,
  };
  EXPECT_EQ(placement, (std::vector<LONG>{107, 210, 102, 204, 116, 218}));
}

} // namespace test
} // namespace oh_my_flutter
