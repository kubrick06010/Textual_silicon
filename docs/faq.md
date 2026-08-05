---
layout: default
title: Frequently asked questions
permalink: /faq/
---

# Frequently asked questions

## What is Textual Silicon?

It is an independent community fork focused on a reliable, native macOS IRC client for Apple Silicon. It retains useful compatibility goals with Textual 7.2.x while removing operational dependencies on the original project.

## Is this the official Codeux Textual project?

No. Textual Silicon is not affiliated with, endorsed by, or supported by Codeux Software, LLC. Historical attributions and third-party licenses remain where they apply; they do not create an operational relationship with the original project.

## Which Macs and macOS versions are supported?

The current target is arm64 on macOS 12.0 or later. Intel compatibility is outside the initial scope. Release notes and CI artifacts are the authority for a particular build.

## Why is a GitHub release unsigned or blocked by macOS?

The automated Apple Silicon artifacts are currently unsigned and not notarized. They are published as prereleases while the project establishes its own Apple Developer identity, bundle identifiers, entitlements, and distribution process. Verify the checksum and download only from the project repository before deciding whether to run a prerelease.

## Can I install it beside the original Textual application?

Do not assume coexistence or automatic migration. Parts of the build still require an explicit identity and data-migration audit. Back up the original data and test with non-primary data until bundle identifiers, App Groups, Keychain access, and migration behavior have been verified together.

## Can I reuse my Textual 7.2.x preferences and connections?

Compatibility is a project goal, not a blanket guarantee for every build or data format. Export or back up preferences, connections, styles, plugins, and logs before testing. Report a migration problem with the source and destination versions, without attaching private data.

## What data does the application handle?

An IRC client necessarily sends connection and message data to the server selected by the user. Textual Silicon may also keep local preferences, connection settings, styles, plugins, and logs; custom scripts and plugins can have additional effects. Review the [Privacy and data](https://kubrick06010.github.io/Textual_silicon/privacy/) notice and the permissions of any extension before using it with sensitive conversations.

## Where are the manuals and release notes?

The maintained manuals and FAQ live in this GitHub Pages site. Release-specific notes belong on the [GitHub Releases](https://github.com/kubrick06010/Textual_silicon/releases) page until the project's update and release-notes service is ready.

## Where do I report a bug?

Open an issue in the [repository issue tracker](https://github.com/kubrick06010/Textual_silicon/issues). Include a reproducible description, environment, version or commit, and sanitized logs. Do not include credentials, license keys, or private conversations.

## How do I report a security vulnerability?

Do not use a public issue. Follow [SECURITY.md](https://github.com/kubrick06010/Textual_silicon/blob/master/SECURITY.md) and use GitHub's private vulnerability reporting when available.

## Can I contribute documentation?

Yes. Edit the Markdown under `docs/`, check links and claims locally, and open a focused pull request. Documentation changes are reviewed like code because inaccurate instructions can cause data loss or unsafe configuration.
