# Dart SDK API source provenance

SDK version: 3.13.1, bundled with Flutter 3.47.1.
Dart revision: 852b3e3608906afbe6102573cfd4407aeedd1b78.
Source: https://github.com/dart-lang/sdk/tree/852b3e3608906afbe6102573cfd4407aeedd1b78/runtime/include

API source/header files, internal header, and LICENSE were copied byte-for-byte from the pinned local SDK. AUTHORS was fetched byte-for-byte from the same upstream revision because the binary SDK omits it. No upstream file was modified. Original copyright/license headers are retained.

SDK C glue is compiled as C, then linked with the C++ backend. It is not compiled as C++ or patched to allow function-pointer conversions.

## SHA-256

```json
{
  "sdk/AUTHORS": "e1ff5b9a21953194e68433e59d1fdb2b1ff52e7598ff282318013cffd5e39805",
  "sdk/LICENSE": "2cfa3ee8e7512e6d44c854b986510810fadc815f93f890373b3a81c1b6ccd256",
  "sdk/include/dart_api.h": "d5009bb2dfa76dcdf3ed3c5bd427a74c4c820cea29f393a5909efa377291f713",
  "sdk/include/dart_api_dl.c": "23ff1b8b9d84bce314a3bd1010d36f1542bf6b618ab220ee8bea48cc7f8c71e4",
  "sdk/include/dart_api_dl.h": "5b290441ad12ee6dcadaea2d14dc7c7791bae533138613afbe9cb699e26917bc",
  "sdk/include/dart_native_api.h": "251f0fd58b315a7b93f43acfc06b5ae433ae51f830fd83f01b08a31b889aa375",
  "sdk/include/dart_version.h": "3517e5639fdf9ed670f94e0acc6637029798085a8768ce258e6954bfca2582a8",
  "sdk/include/internal/dart_api_dl_impl.h": "5b54388565d2e363fa760bdd847b33242cc4d9eb0167fa03fbaa8b2778581c57"
}
```
