---
layout: default
title: Privacy and data
permalink: /privacy/
---

# Privacy and data

This is the current project-level data-handling notice for Textual Silicon. It describes the open-source fork and its documentation site; it is not a final legal privacy policy for every future binary, service, or distribution channel.

## What the application can handle

- IRC connection details and authentication settings entered by the user;
- messages and events exchanged with the IRC servers selected by the user;
- local preferences, styles, plugins, scripts, and conversation logs; and
- diagnostic information created when the user chooses to inspect or report a problem.

The exact data retained depends on the selected features, server, plugins, scripts, and local preferences. A server operator can apply its own logging and retention policy; Textual Silicon cannot control that policy.

## Extensions and web content

Custom scripts, plugins, inline media, and styles are code or active content. They may access resources beyond the core client according to their implementation and the macOS sandbox rules. Install only extensions you trust and review their source and network behavior where possible.

## Reports and support

Issue reports and pull requests are public unless GitHub provides a private reporting path. Remove credentials, license keys, private messages, server passwords, certificates, personal identifiers, and full log archives before submitting anything. Use the process in [SECURITY.md](https://github.com/kubrick06010/Textual_silicon/blob/master/SECURITY.md) for suspected vulnerabilities.

## Project services

The project is separating its documentation, support, release, and update services from Codeux infrastructure. A build or extension may still contain legacy operational code while that work is in progress; check the release notes and source for the exact behavior of the build you use.

## Changes

This notice will be updated with the source repository as the project establishes its own signed distribution, update channel, telemetry policy, and migration rules. Do not infer a future service's data practices from this draft.
