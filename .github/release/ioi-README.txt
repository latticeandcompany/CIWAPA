INTERCAL on Interstates
=======================

This archive holds one flavor of INTERCAL on Interstates, the web framework nobody asked for, and
everything it needs to build and serve sites:

  bin/ioi-dart or     CIWAPA's compiler of that flavor, which builds INTERCAL on Interstates sites
  bin/ioi-llvm        from .ioi files (and plain EXTRACAL programs, .xc to .7xc)
  bin/gross           the development server, which runs a site's program once per request
  lib/                ActiveCassette's SQLite: an object ioi-llvm links into sites that use a
                      database, or the library ioi-dart sites load
  dart-sdk/ or        the toolchain the compiler builds with, as in the matching ciwapa-* archive
  toolchain/
  licenses/           the license of every component in this archive

Nothing needs installing, apart from the macOS LLVM flavor, which uses Apple's clang (run
`xcode-select --install` once if `ioi-llvm doctor` says it's missing). On Linux the bundled clang
needs libstdc++, zlib and libgcc_s, which every mainstream distribution has.

Put bin/ on your PATH, or run the programs in it directly. Keep the folder together: the compiler
finds its toolchain and lib/ next to bin/.

Hello, world
------------

  hello.ioi       DO COME FROM (16000)
                  PLEASE READ OUT #0 WITH TEMPLATE "hello.html"
                  GIVE UP

  hello.html      <h1>Hello, world!</h1>

  ioi-<flavor> build --no-random-bug hello.ioi -o hello
  gross ./hello

Then open http://127.0.0.1:10585/. `gross --help` lists its flags: --static <dir> serves files,
--database sqlite:<file> gives the site a database.

Sites built with the Dart flavor load lib/'s SQLite from where it was when they were built, so
rebuild them if you move this folder.

Unsigned binaries
-----------------

The binaries aren't signed, so the first run can be blocked:

  macOS (Gatekeeper)       remove the download quarantine from the unpacked folder:
                             xattr -dr com.apple.quarantine ioi-*
  Windows (SmartScreen)    choose "More info", then "Run anyway". Or unblock the zip
                           before unpacking it: right-click, Properties, Unblock.
