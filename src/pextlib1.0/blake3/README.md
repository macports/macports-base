BLAKE3 C Implementation - Vendored Copy
========================================

Version
-------
1.8.4 (git commit b97a24f)

Source
------
This directory contains a subset of the BLAKE3 reference C implementation,
taken from the official BLAKE3 repository:

  https://github.com/BLAKE3-team/BLAKE3

Directory layout
----------------
- `src/` — Pristine upstream sources from the c/ subdirectory of the
  BLAKE3 repository, unmodified.
- `patches/` — MacPorts-specific patches applied at build time.
- `LICENSE_*` — Upstream licence files.

Files included in src/
----------------------
- `blake3.c` — Core implementation
- `blake3.h` — Public API header
- `blake3_dispatch.c` — Runtime CPU feature dispatch
- `blake3_impl.h` — Internal implementation header
- `blake3_portable.c` — Portable C (no SIMD) backend
- `blake3_neon.c` — ARM NEON backend
- `blake3_sse2_x86-64_unix.S` — x86-64 SSE2 assembly backend (Unix)
- `blake3_sse41_x86-64_unix.S` — x86-64 SSE4.1 assembly backend (Unix)
- `blake3_avx2_x86-64_unix.S` — x86-64 AVX2 assembly backend (Unix)
- `blake3_avx512_x86-64_unix.S` — x86-64 AVX-512 assembly backend (Unix)

Not included:

- `blake3_tbb.cpp` — TBB multithreading backend
- `blake3_*_windows_*.S` / `*.asm` — Windows assembly sources
- Build system files (CMakeLists.txt, etc.)

These are not needed for the macports-base pextlib use case.

License
-------
BLAKE3 is released under a triple licence; you may use it under any of:

  CC0 1.0 Universal (public domain dedication)  — see LICENSE_CC0
  Apache License 2.0                             — see LICENSE_A2
  Apache License 2.0 with LLVM Exceptions       — see LICENSE_A2LLVM

Build integration
-----------------
The autoconf-generated config.h (which carries the BLAKE3_NO_SSE2,
BLAKE3_NO_SSE41, etc. defines set by configure) is injected into the
vendored sources via the compiler's -include flag rather than by
modifying the upstream headers.

Patches
-------
Patches in patches/ are applied to a copy in the build tree at build
time; the files in src/ are never modified.  Currently there is one
patch:

blake3_dispatch.c.patch:
  - Removed the GCC-path #include <immintrin.h>.  Nothing in the GCC
    inline-asm cpuid/dispatch path requires it; its presence caused
    compilation failures on older Xcode/GCC toolchains that predate
    the AVX intrinsics header.
  - Replaced the "xgetbv" inline-assembly mnemonic with its raw byte
    encoding (.byte 0x0f, 0x01, 0xd0).  The xgetbv mnemonic was
    introduced with the AVX/XSAVE documentation and is not recognised
    by the assembler shipped with Xcode 3 (OS X 10.5 era), yet the
    function must compile whenever any x86 SIMD backend is enabled.
    The raw encoding is functionally identical and assembles correctly
    on all supported toolchains.

Updating
--------
To update the vendored sources:
  1. Update src/ with the new upstream files from the c/ directory.
  2. Check whether patches/ still applies cleanly; adjust if needed.
  3. Update the version noted at the top of this file.
