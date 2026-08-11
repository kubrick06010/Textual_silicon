---
layout: default
title: User guide
permalink: /user-guide/
---

# User guide

This guide covers the current Textual Silicon fork. It is deliberately conservative where behavior is still being compared with Textual 7.2.x.

## Installation

Download releases only from the project's [GitHub Releases](https://github.com/kubrick06010/Textual_silicon/releases) page. Before opening an archive:

1. Confirm that the release is intended for Apple Silicon (`arm64`).
2. Download the accompanying SHA-256 checksum when one is provided and verify the archive locally.
3. Keep in mind that current automated artifacts are ad hoc signed and not notarized. macOS may require an explicit user approval before opening them.
4. If Finder reports that `Textual.app` is damaged after the checksum passes, remove the quarantine flag from the extracted app in Terminal:

   ```sh
   xattr -dr com.apple.quarantine /path/to/Textual.app
   open /path/to/Textual.app
   ```

   This is a Gatekeeper workaround for the current prerelease distribution; it does not replace Developer ID signing and notarization.

Do not treat an ad hoc signed prerelease as a production or security-reviewed distribution. The release notes and the repository are the source of truth for each build.

## First connection

Create or select a network and provide the connection details supplied by your IRC network:

- server hostname and port;
- TLS or plain-text transport as required by the network;
- nickname and username;
- authentication details, if the network requires them; and
- channels to join after connecting.

IRC networks differ in their authentication and channel policies. If a connection fails, record the server response and the exact version before opening an issue, but redact credentials and private conversation content.

## Certificate authentication

For networks that require a client certificate, select an identity from the macOS Keychain in the server properties. The certificate must be intended for client authentication and its private key must be available to the same user account that runs Textual Silicon. Never attach a private key or certificate bundle to an issue.

## Bouncers

IRC bouncers such as ZNC can change playback, capability negotiation, and connection state. Follow the bouncer's own configuration instructions, then record whether the connection is direct or proxied when troubleshooting. Do not share bouncer passwords or certificates.

## File transfers

Textual supports IRC DCC file-transfer flows. Treat incoming transfers as untrusted: verify the sender, destination, and file before opening it. Do not accept a transfer merely because it appears in a trusted channel.

## Command reference

The command reference is built from the commands supported by the current application. For the less common defaults commands, the application itself exposes:

```text
/defaults help
/defaults features
```

Commands can vary with server capabilities, plugins, and build features. When documenting a new command, include its parser behavior and a focused test where possible.

## Keyboard shortcuts

Use the application menus as the authoritative source for the shortcuts enabled by the current build. macOS menu titles and configured key equivalents take precedence over a copied shortcut list. Report a shortcut conflict with the affected menu title and macOS version.

## Text formatting

IRC formatting is interpreted by the server and by the active style. Test formatting in a low-risk channel before relying on it for moderation or automation, and remember that different clients may render the same formatting differently.

## Message presentation

Choose **Preferences > Style > General > Message presentation** to switch between the traditional `Classic IRC` layout and the denser `Chat` layout. `Classic IRC` remains the default. `Chat` uses compact sender and time columns and suppresses repeated metadata only for consecutive messages from the same sender. Ordinary messages and `/me` actions form separate groups; switching type, highlights, other events, date or session boundaries, and pauses longer than five minutes start a new visual group.

Changing the presentation updates open conversations without reloading their history. Bundled styles support both modes. A custom style that replaces the message template may need to adopt the current default template tokens before `Chat` can reproduce the same grouping and alignment.

## Chat encryption

When the optional advanced-encryption components are present, private conversations may expose Off-the-Record (OTR) actions. Verify fingerprints with the other participant through an independent channel before treating a conversation as authenticated. OTR does not make a public channel private and does not protect against a compromised endpoint.

## Scripts and styles

Textual supports custom styles and scripts. Treat both as code: install only content you trust, review permissions and network access, and keep backups before changing a working configuration.

The application can load custom scripts from the macOS application-scripts directory associated with the installed bundle. The exact bundle identifier is part of the ongoing identity migration, so use the installation's current documentation and do not assume that a directory from another Textual build is interchangeable.

For style and script questions, include the relevant file and the application version. Do not upload private logs or credentials with a report.

## Chat filters

The Chat Filter add-on can match message content or sender information and apply actions to matching events. The help buttons in the add-on point to these sections:

- [matching rules](#chat-filter-matching);
- [actions](#chat-filter-actions);
- [sender matching](#chat-filter-senders); and
- [forwarding to another destination](#chat-filter-forwarding).

### Chat filter matching

Define a match that is as narrow as possible for the events you intend to filter. Test it in a low-risk channel before enabling it broadly. Preserve the original pattern when reporting a problem, but remove private names or message content.

### Chat filter actions

An action changes how a matching event is displayed or handled. Review the selected action and its destination before saving the filter; an overly broad rule can hide or redirect messages unexpectedly.

### Chat filter senders

Sender constraints limit a filter to selected users or identities. Prefer stable, intentional identifiers over a broad wildcard when the network supports changing nicknames.

### Chat filter forwarding

Forwarding can disclose message content to another destination. Confirm the destination and its access policy before enabling it, and never forward credentials or private conversations without consent.

## Preferences and data

Back up preferences, connections, styles, plugins, and logs before changing builds or testing a migration. The project aims to retain useful compatibility with Textual 7.2.x, but the migration is not considered complete until it has been verified on representative data.

Keep old and new installations isolated while bundle identifiers, App Groups, Keychain access, and migration rules are being finalized. Do not delete the original data to solve a startup or migration problem.

### Data migration

Some builds may offer to move files between legacy and sandboxed locations. Read the prompt, keep the original copy until the new build has been tested, and record the source and destination versions if the migration fails. A migration prompt is not proof that every preference, plugin, log, or credential was copied safely.

## Troubleshooting

When reporting a reproducible problem, include:

- the app version or commit;
- macOS version and Mac model;
- whether the build is Apple Silicon or translated;
- exact steps to reproduce;
- the expected and observed result; and
- relevant logs with credentials, license keys, private messages, and personal information removed.

If the app cannot connect, also include the network type, port and TLS mode, but never include passwords, SASL secrets, or private certificates.

### Network timeouts

Check the hostname, port, TLS mode, local firewall, and the IRC network's availability before increasing a timeout. A longer timeout can make a failed connection appear hung and does not repair certificate, authentication, or server-capability problems.

## Getting help

Use the [GitHub issue tracker](https://github.com/kubrick06010/Textual_silicon/issues) for bugs and feature requests. Community discussion is available in `#textual` on `irc.libera.chat`. Security vulnerabilities must be reported privately according to [SECURITY.md](https://github.com/kubrick06010/Textual_silicon/blob/master/SECURITY.md). The project's current data-handling notice is [Privacy and data](https://kubrick06010.github.io/Textual_silicon/privacy/).
