---
layout: default
title: Documentation
description: User and developer documentation for Textual Silicon.
permalink: /
---

# Textual Silicon documentation

Textual Silicon is an independent macOS IRC client project focused on a reliable, native Apple Silicon build while retaining useful compatibility with Textual 7.2.x.

> This project is not affiliated with, endorsed by, or supported by Codeux Software, LLC. Historical copyright and third-party license notices remain part of the source where applicable.

The documentation is versioned with the source repository. If a behavior is still being verified, the guide says so rather than treating the original Codeux documentation as authoritative for this fork.

<div class="cards">
  <section class="card">
    <h2><a href="{{ '/user-guide/' | relative_url }}">User guide</a></h2>
    <p>Install a build, connect to IRC, use scripts and styles, protect your data, and get support.</p>
  </section>
  <section class="card">
    <h2><a href="{{ '/developer-guide/' | relative_url }}">Developer guide</a></h2>
    <p>Clone the repository, build for arm64, run tests, understand the layout, and contribute safely.</p>
  </section>
  <section class="card">
    <h2><a href="{{ '/faq/' | relative_url }}">FAQ</a></h2>
    <p>Short answers about compatibility, releases, privacy, support, and the transition away from upstream services.</p>
  </section>
</div>

## Current project status

- The supported target is Apple Silicon (`arm64`).
- The project currently targets macOS 12.0 or later.
- Automated release artifacts are currently ad hoc signed and not notarized. They are published as GitHub prereleases until the project has its own Developer ID distribution identity and production entitlements.
- Compatibility with existing Textual preferences, connections, styles, plugins, and logs is a project goal, but migration should be backed up and tested before relying on it.

## Where to ask for help

Use the [issue tracker](https://github.com/kubrick06010/Textual_silicon/issues) for reproducible problems and feature requests. For security issues, follow the private process in [SECURITY.md](https://github.com/kubrick06010/Textual_silicon/blob/master/SECURITY.md). Never post IRC credentials, license keys, private logs, or other sensitive data.
