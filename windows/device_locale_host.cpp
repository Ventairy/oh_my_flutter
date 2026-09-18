#include "device_locale_host.h"
#include <utility>

namespace oh_my_flutter {

DeviceLocaleHost::DeviceLocaleHost(RegionReader reader) : reader_(std::move(reader)) {}

int DeviceLocaleHost::ReadRegion(wchar_t* buffer, int size) {
  // Resolve at runtime so older Windows versions can return unavailable safely.
  const auto library = GetModuleHandleW(L"kernel32.dll");
  if (library == nullptr) return 0;
  using GetRegion = int(WINAPI*)(LPWSTR, int);
  const auto read = reinterpret_cast<GetRegion>(GetProcAddress(library, "GetUserDefaultGeoName"));
  return read == nullptr ? 0 : read(buffer, size);
}

device_locale::ErrorOr<std::optional<std::string>> DeviceLocaleHost::GetCountry() {
  wchar_t buffer[4] = {};
  const auto length = reader_(buffer, 4);
  if (length != 3 || buffer[2] != L'\0') return std::optional<std::string>();
  std::string code;
  for (int i = 0; i < 2; ++i) {
    const auto value = buffer[i];
    if (!((value >= L'A' && value <= L'Z') || (value >= L'a' && value <= L'z'))) {
      return std::optional<std::string>();
    }
    code.push_back(static_cast<char>(value));
  }
  return std::optional<std::string>(code);
}

}  // namespace oh_my_flutter
