# Getting Started

This page shows how to wire `almakefiles` into a consumer project and what to expect from the first normal run.
For runtime support and public guarantees, read [`contracts.md`](contracts.md) first.

## Add The Drop-In

Put the drop-in directory anywhere relative to the consumer project root and add one literal include line to the consumer Make entrypoint.

Inside the project:

```make
include almakefiles/include.mk
```

Nested inside the project:

```make
include tools/dev-layer/include.mk
```

Outside the project:

```make
include ../shared/dev-layer/include.mk
```

If the project uses a non-default Make entrypoint filename, invoke it explicitly:

```bash
make -f path/to/entrypoint help
```

## First Normal Run

On a normal top-level run such as `make help`, `almakefiles` renders `help` from the active module set and active generated targets.
Depending on the project state, the same run can also:

- create and validate `ALMKFS_ENV_FILE` when it is missing
- initialize missing regular `.env*` files when matching `.env*.example` files exist

If a declared env target has no matching `.env*.example` file, the run fails instead of guessing a source file.

Query-style invocations such as `-n`, `-p`, `-q`, and `-pnRr` must not create or rewrite files.

## Useful Follow-Up Commands

- `make help`
  - list the active public targets
- `make var.debug`
  - show variable winners for discovered `?=` defaults
- `make var.debug-full`
  - show the full winner report from the active Make database

Use [`reference.md`](reference.md) for a quick surface-area lookup.
Use [`common.md`](modules/common.md), [`env.md`](modules/env.md), [`docker-compose.md`](modules/docker-compose.md), and [`git.md`](modules/git.md) for module-specific details.
