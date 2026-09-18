#include "device_locale_host.h"
#include <gtest/gtest.h>
#include <algorithm>
#include <string>

namespace oh_my_flutter {

TEST(DeviceLocaleHostTest, WhenCountryIsConfiguredItShouldReturnItsCode) {
  DeviceLocaleHost host([](wchar_t* buffer, int) {
    std::copy_n(L"BR", 3, buffer);
    return 3;
  });
  EXPECT_EQ(host.GetCountry().value(), std::optional<std::string>("BR"));
}

TEST(DeviceLocaleHostTest, WhenReadingFailsItShouldReturnNull) {
  DeviceLocaleHost host([](wchar_t*, int) { return 0; });
  EXPECT_EQ(host.GetCountry().value(), std::nullopt);
}

TEST(DeviceLocaleHostTest, WhenRegionIsNumericItShouldReturnNull) {
  DeviceLocaleHost host([](wchar_t* buffer, int) {
    std::copy_n(L"419", 4, buffer);
    return 4;
  });
  EXPECT_EQ(host.GetCountry().value(), std::nullopt);
}

TEST(DeviceLocaleHostTest, WhenRegionChangesItShouldReadTheNewValue) {
  int calls = 0;
  DeviceLocaleHost host([&calls](wchar_t* buffer, int) {
    std::copy_n(calls++ == 0 ? L"BR" : L"US", 3, buffer);
    return 3;
  });
  const auto first = host.GetCountry().value();
  EXPECT_EQ(std::make_pair(first, host.GetCountry().value()),
            std::make_pair(std::optional<std::string>("BR"), std::optional<std::string>("US")));
}

}  // namespace oh_my_flutter
