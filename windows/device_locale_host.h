#ifndef FLUTTER_PLUGIN_DEVICE_LOCALE_HOST_H_
#define FLUTTER_PLUGIN_DEVICE_LOCALE_HOST_H_

#include <windows.h>
#include <functional>
#include "device_locale.g.h"

namespace oh_my_flutter {

class DeviceLocaleHost : public device_locale::DeviceLocaleHostApi {
 public:
  using RegionReader = std::function<int(wchar_t*, int)>;
  explicit DeviceLocaleHost(RegionReader reader = ReadRegion);
  device_locale::ErrorOr<std::optional<std::string>> GetCountry() override;

 private:
  static int ReadRegion(wchar_t* buffer, int size);
  RegionReader reader_;
};

}  // namespace oh_my_flutter
#endif
