# Competitor research and product decisions

Research was performed against current first-party product pages and manuals in September 2026.

## Patterns worth adopting

| Product | Strongest ideas | Mac Commander decision |
|---|---|---|
| [Marta](https://marta.sh/) | Native Swift speed, keyboard/mouse parity, archive-as-folder, command palette, task queue, disk usage, two-way terminal directory synchronization | Native Swift with no dependencies; independent two-way pane terminals; operation status; provider seam reserved for archives |
| [Nimble Commander](https://github.com/mikekazakov/nimble-commander/blob/main/Docs/Help.md) | Orthodox dual-pane selection, deep keyboard control, regex/content/size search, temporary result panels, viewer, batch rename, virtual filesystems | F-key strip and Tab pane switching; regex/content/exclusion search; results become a normal actionable pane tab; Quick Look for preview |
| [ForkLift](https://www.binarynights.com/manual) | Dual-pane local/remote work, folder comparison and synchronization, transfer queue, saved sync configurations | Local copy/move queue first; comparison/sync and provider-backed locations are the next major layer |
| [Path Finder](https://support.cocoatech.com/hc/en-us/articles/43462660340244-Path-Finder-User-Interface-Overview) | Modular macOS interface, dual-pane view, Drop Stack, terminal and metadata tools | Keep the default layout focused; add optional utility surfaces only when they preserve pane density |
| [Commander One](https://commander-one.com/manual/) | Familiar F-key command bar, unlimited tabs, list/column/icon views, advanced search, archives, remote/cloud connections, terminal, operation queue | Always-visible F-key bar, tabs and list/grid views, direct search, per-pane terminal, native Open With bar, visible operation progress |

## Essential roadmap

Ordered by user value and implementation risk:

1. **Trustworthy operations:** cancellable queue, pause/resume, explicit replace/skip/keep-both conflict rules, retry, and an operation log.
2. **Fast selection:** type-to-jump, wildcard/regex select and deselect, invert selection, and Shift-range selection independent from the cursor.
3. **Batch rename:** previewable find/replace, numbering, case conversion, regular expressions, and saved presets.
4. **Archives as folders:** browse ZIP/TAR in a pane, extract/copy through normal F-key operations, and create ZIP safely.
5. **Compare and synchronize:** two-pane folder diff with one-way, two-way, and mirror modes; always preview destructive changes.
6. **Search upgrades:** metadata predicates, size/date ranges, saved searches, duplicate detection, and result ranking.
7. **File information and permissions:** inspector, tags, checksums, extended attributes, ownership, and chmod-compatible permissions.
8. **Extensibility:** configurable hotkeys, command palette, external tools, and a `chadcommander` CLI launcher.
9. **Remote locations:** SFTP first, then SMB/WebDAV and cloud providers behind a tested virtual-filesystem layer.

Default-folder handling is useful integration rather than a core operation. It should remain reversible and must not pretend to replace Finder-owned Desktop or Open/Save surfaces.

## Scope chosen for the first shippable build

The fastest coherent product is a trustworthy local file manager. Local traversal, selection, copy/move/rename/new-folder/Trash, application launching, Quick Look, tabs, direct search, drag/drop, and per-pane terminals therefore ship together. These workflows share one filesystem model and can be tested without credentials or third-party SDKs.

Remote/cloud providers, archives-as-folders, folder diff/sync, batch rename templates, a Drop Stack, and disk-usage visualization are valuable but should not be thin UI wrappers around shell commands. They belong behind explicit provider and operation protocols with conflict resolution, authentication, progress, cancellation, retry, and tests. The current real/virtual tab split is intentionally compatible with that extension.

## Safety choices

- Delete means macOS Trash, with confirmation. There is no permanent-delete shortcut.
- Copy and move never overwrite a conflict silently. A unique `copy` name is generated.
- Content search skips binary files and caps each content scan at 64 MB by default.
- File operations and scans run off the main actor so directory interaction remains responsive.
- The package has no network code, analytics, or third-party dependencies.
