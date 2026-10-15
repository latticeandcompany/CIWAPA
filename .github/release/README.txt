CIWAPA: an INTERCAL compiler
============================

This archive holds one CIWAPA compiler and everything it needs to build programs:

  bin/ciwapa-dart     the Dart flavor, with the Dart SDK it uses in dart-sdk/
  bin/ciwapa-llvm     the LLVM flavor, with clang and lld in toolchain/
                      (on Linux also a static musl sysroot; on Windows, llvm-mingw)
  licenses/           the license of every component in this archive

Nothing needs installing, apart from the macOS LLVM flavor, which uses Apple's clang
(run `xcode-select --install` once if `ciwapa-llvm doctor` says it's missing).

Usage
-----

  ciwapa-<flavor> doctor              check the toolchain
  ciwapa-<flavor> build prog.i        compile prog.i into ./prog
  ciwapa-<flavor> run prog.i          compile and run it at once
  ciwapa-<flavor> --help              every flag

Files ending in .3i to .7i are TriINTERCAL programs in bases 3 to 7.

Unsigned binaries
-----------------

The binaries aren't signed, so the first run can be blocked:

  macOS (Gatekeeper)       remove the download quarantine from the unpacked folder:
                             xattr -dr com.apple.quarantine ciwapa-*
  Windows (SmartScreen)    choose "More info", then "Run anyway". Or unblock the zip
                           before unpacking it: right-click, Properties, Unblock.
