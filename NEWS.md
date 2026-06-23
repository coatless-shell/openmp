# openmp 1.2.0 (2026-06-23)

## New features

- Added `sync-openmp.sh` to keep the pinned OpenMP version data in sync with the
  upstream R CRAN macOS tools page (<https://mac.r-project.org/openmp/>). It
  regenerates the clang version `case` block and `--help` listing in
  `install-openmp.sh` and the Supported Versions table in `README.md`, recomputing a
  tarball's SHA1 only when its version changes. Run `./sync-openmp.sh` to apply
  updates or `./sync-openmp.sh --check` for a non-mutating drift check.
- Added a weekly `Check OpenMP upstream` GitHub Actions workflow that runs the sync
  and opens a pull request only when upstream has changed.
- Added `test-openmp.sh` and an `OpenMP correctness` GitHub Actions workflow on
  `macos-14` and `macos-15` that compile and run OpenMP code in both C and a minimal
  R package against the installed runtime, asserting real multithreading and a
  deterministic parallel-reduction result. Use `--c-only` to skip the R check.

## OpenMP runtime

- Updated the Apple clang `1700.x` (Xcode 16.3+) tier from OpenMP 19.1.0 to 19.1.5.

## Bug fixes and internals

- Fixed the README "Supported Versions" table, which rendered broken because a
  generated-block comment fell between the table separator row and the first data
  row.
- Bumped pinned GitHub Actions: `actions/checkout` to v7 and
  `peter-evans/create-pull-request` to v8.

# openmp 1.1.0 (2025-11-18)

- Added a command-line flag to reinstall the OpenMP runtime non-interactively, for
  CI and scripted use.

# openmp 1.0.0 (2025-08-26)

Initial release — three dependency-free shell scripts for installing, diagnosing,
and removing OpenMP on macOS using Apple's Xcode Clang toolchain.

- `install-openmp.sh` detects the Apple clang version and installs the matching
  OpenMP runtime from the R CRAN macOS tools page, validating the download against a
  pinned SHA1 checksum.
- `check-openmp.sh` compiles and runs a small OpenMP program to diagnose the
  installation and configuration, with a `--disable-r` flag for C/C++-only testing.
- `uninstall-openmp.sh` removes the installed OpenMP runtime.
