# Android C++ runtime license provenance

Android builds link the C++ runtime statically. Complete upstream license and
attribution texts for libc++, libc++abi, and libunwind are preserved in the
component folders and included in Flutter's application license collection.

The texts are copied without modification from Android's LLVM source revision
`97a699bf4812a18fb657c2779f5296a4ab2694d2`, used by NDK 28.2.13676358 (r28c):

- https://android.googlesource.com/toolchain/llvm-project/+/97a699bf4812a18fb657c2779f5296a4ab2694d2/libcxx/LICENSE.TXT
- https://android.googlesource.com/toolchain/llvm-project/+/97a699bf4812a18fb657c2779f5296a4ab2694d2/libcxxabi/LICENSE.TXT
- https://android.googlesource.com/toolchain/llvm-project/+/97a699bf4812a18fb657c2779f5296a4ab2694d2/libunwind/LICENSE.TXT

SHA-256:

- libcxx: `539dd7aed86e8a4f12cbdd0e6c50c189c7d74847e4fecc64ce2c6ee3a01da38b`
- libcxxabi: `e2b35be49f7284a45b7baca8fc7b3ab7440e7902392b2528a457816b5bb2a15c`
- libunwind: `b5efebcaca80879234098e52d1725e6d9eb8fb96a19fce625d39184b705f7b6d`
