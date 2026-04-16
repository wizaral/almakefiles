# Contracts

This document defines the public guarantees that consumer projects may rely on.
Module-specific behavior lives in [`common.md`](modules/common.md), [`env.md`](modules/env.md), [`docker-compose.md`](modules/docker-compose.md), and [`git.md`](modules/git.md).

## Runtime Support Contract

Supported runtime today is:

- GNU Make
- Bash 4.3+
- GNU userland tools such as `realpath --relative-base`, `find -printf`, and `chmod --reference`

This is a Linux-style GNU runtime contract.
Stock macOS is not supported out of the box.

## Entrypoint And Path Contract

- The first include is always a literal path to `include.mk`.
- No public variable participates in resolving that first include.
- `ALMKFS_DIRECTORY_PATH` is computed from the actual loaded path, not from a user-supplied mirror of that path.
- Re-including the same canonical `include.mk` path is harmless.
- Loading a different canonical `include.mk` path in the same run is a hard error.
- The published path is canonical:
  - project-root-relative when the drop-in lives inside the consumer project
  - absolute when the drop-in lives outside the consumer project

## Local Make Config Contract

- `ALMKFS_ENV_FILE` is the only public override for the generated Make-local config file.
- `.env.mk` is a validated Make-local config file, not a generic Make fragment.
- Default placement depends on the drop-in location:
  - inside the project: `$(ALMKFS_DIRECTORY_PATH)/.env.mk`
  - outside the project: `.env.mk` in the consumer project root
- `ALMKFS_ENV_FILE` is excluded from normal `.env*` discovery and from `?=` autogeneration feedback loops.

Allowed `.env.mk` lines:

- blank lines
- `# ...` comments
- `NAME = value`
- `NAME := value`
- `NAME ::= value`
- `NAME += value`

Allowed `.env.mk` variable names:

- public `ALMKFS_*`
- consumer project variables

Forbidden `.env.mk` content:

- GNU Make system variables
- `__ALMKFS_*`
- directives, conditionals, includes, rules, or targets

## Cross-Module Execution Contract

- Normal top-level runs may bootstrap `ALMKFS_ENV_FILE`.
- Normal top-level runs may initialize missing regular `.env*` files only from matching `.env*.example` files.
- Query-style invocations such as `-n`, `-p`, `-q`, and `-pnRr` must not create or rewrite `.env.mk` or regular `.env*` files.
- `help` shows only targets from active modules and active generated target families.
- `help` renders its final target list in deterministic global `LC_ALL=C` lexical order.
- Disabled modules disappear consistently from `help` and from `.env.mk` default scanning.

For env-file provenance rules, compose target semantics, and git clean behavior, use the matching module documents.

## Naming Contract

- Public project-owned Make variables use the `ALMKFS_` prefix.
- Private project-owned Make variables use the `__ALMKFS_` prefix.
- `ALMKFS_* ?=` declares a supported configurable default.
- `override ALMKFS_*` declares a computed public value.
- `override __ALMKFS_*` declares private internal state.
- Consumer project variables remain unprefixed unless the project chooses otherwise.
