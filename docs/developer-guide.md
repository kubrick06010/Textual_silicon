---
layout: default
title: Developer guide
permalink: /developer-guide/
---

# Developer guide

Textual Silicon is an Objective-C, Swift, Xcode-based macOS project. Keep changes small, buildable, and independently verifiable. The repository's local engineering guide and roadmap describe the wider direction.

## Prerequisites

- macOS with Xcode and its command-line tools installed;
- an Apple Silicon Mac or an arm64-capable build environment;
- Git with submodule support; and
- enough disk space for Xcode build products and the bundled dependencies.

The project currently targets macOS 12.0 or later and arm64. Distribution signing, notarization, bundle identifiers, App Groups, and update feeds are intentionally separate work from this documentation change.

## Clone the source

The repository depends on source held in submodules. Clone it and initialize those dependencies before opening the project:

```sh
git clone https://github.com/kubrick06010/Textual_silicon.git
cd Textual_silicon
git submodule update --init --recursive
```

Opening the project from a ZIP archive without its submodules produces an incomplete checkout.

## Build and run

The checked-in helper builds and launches the Debug scheme for arm64:

```sh
./script/build_and_run.sh --verify
```

Other supported modes are `run`, `--debug`, `--logs`, and `--telemetry`. The script writes build diagnostics under `.tmp/Script-Logs`; those files are local artifacts and must not be committed.

For direct Xcode or `xcodebuild` work, the relevant project is `Sources/App/Textual App.xcodeproj`. The current schemes are:

- `Textual (Debug)`;
- `Textual (Standard Release)`;
- `TextualCoreTests`; and
- `Build Frameworks`.

Keep `arm64` explicit in local and CI builds. A local ad hoc signature is acceptable for development when the selected configuration permits it; do not introduce a distribution identity or credentials into the repository.

## Tests and verification

Run the narrowest test target that covers the change, then build the affected application scheme. Protocol parsing, byte limits, state machines, persistence, XPC boundaries, and connection behavior deserve focused tests before UI smoke tests.

At minimum, review the result with:

```sh
git diff --check
git status --short
```

Do not add DerivedData, build products, logs, credentials, or private documentation to a commit.

## Repository layout

- `Sources/App`: application code, resources, plugins, and the main Xcode project.
- `Sources/App/Tests`: focused core tests.
- `XPC Services`: isolated connection, history, and inline-content services.
- `Frameworks`: bundled frameworks and static libraries with their own licenses.
- `Configurations`: shared build, sandbox, and export settings.
- `script`: repeatable local build and smoke-test helpers.
- `docs`: public user and developer documentation, published through GitHub Pages.

## Documentation workflow

Documentation is source code. Edit Markdown in `docs/`, keep links relative to the site, and verify claims against the current code or a reproducible build. Pull requests build the Pages artifact; only `master` deploys it.

On the first merge, a maintainer must enable GitHub Pages in the repository settings and select GitHub Actions as the publishing source. The deployment job uses the `github-pages` environment and refuses to deploy pull requests or non-`master` refs.

Write original project documentation. Do not copy Codeux-hosted manuals or other third-party text into this repository unless its license and provenance have been verified. Preserve historical copyright and third-party notices where the source requires them.

## Release workflow

Pull requests and pushes to `master` build the ad hoc signed Apple Silicon app and
retain it as a workflow artifact. An annotated tag beginning with `v` publishes
the same package as a GitHub prerelease with generated notes and a SHA-256
checksum:

```sh
git switch master
git pull --ff-only
git tag -a v7.2.7-1 -m "Textual Silicon v7.2.7-1"
git push origin v7.2.7-1
```

Treat release tags as immutable. If a build must be replaced, fix the source
and publish a new tag. A workflow retry may replace assets attached to the
same existing release, but it does not move or create an unpushed tag. Until
the project has its own audited distribution identity, these packages remain
ad hoc signed, unnotarized prereleases and must not be described as production
distribution builds.

## Security and compatibility

Never commit IRC credentials, signing material, update keys, private endpoints, user logs, or license keys. When changing identifiers, persistence, sandboxing, TLS, WebKit, XPC, or bundled dependencies, document the migration and test the failure path as well as the happy path.

Compatibility with existing Textual 7.2.x data is valuable, but it is not permission to silently overwrite legacy data. Back up first, make migrations explicit, and keep legacy aliases separate from the project's final identity.

## Diagnostics and memory

For crashes, hangs, or memory growth, collect the smallest diagnostic that demonstrates the problem. Prefer a reproducible test, a sanitized log excerpt, or a macOS diagnostic report over a full user data directory. Check object lifetime, XPC termination, WebKit content, and long-running IRC buffers before attributing growth to a single allocation.

## Pull requests

Keep one observable result per pull request. Explain the problem, hypothesis, implementation, and verification. Update the user guide or FAQ when a user-visible workflow changes, and update this guide when the build or contribution workflow changes.
