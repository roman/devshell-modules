---
socrates_format: 2
id: 6f37-declared-files
status: approved
priority: 1
category: functional
assignee:
serves: [RC1, AC1]
deps: [887e-strict-shell-modules]
---

# Materialize declared files

## Scope

This task implements a narrow v1 `files` surface for generated text,
format-generated content, and source paths. Shell entry creates project-relative
symlinks to immutable sources. It can replace a symlink created for the same
declared path and fails when a regular file or unmanaged symlink occupies that
path. Seed mode, copy mode, orphan cleanup, ownership databases, and concurrent
entry coordination remain outside v1 because they require a stateful file
lifecycle.

## Outcome

- Modules declare generated text, format-generated content, and source paths
  through the supported option shapes.
- Shell entry links each declared path to its immutable source.
- Re-entry updates a previously managed link and preserves unmanaged paths.
- Path conflicts stop before an unmanaged artifact changes.

## Verification

- A temporary project observes the expected content for text, format-generated,
  and source declarations after shell entry.
- Re-entry updates a link previously created for the same declared path.
- A regular file and an unmanaged symlink each cause a focused collision error
  and remain unchanged.
- Two declarations targeting one path fail before either link is changed.

<review></review>
