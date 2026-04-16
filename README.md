# almakefiles

`almakefiles` is a drop-in GNU Make layer for local development workflows.
Add one include line to a consumer project and get environment bootstrap, focused `help`, and reusable convenience targets without copying the same Make glue into every repository.

## What It Gives You

- active-target `help` output instead of a hand-maintained command list
- automatic `.env.mk` bootstrap from discovered `?=` defaults
- regular `.env*` initialization from matching `.env*.example` files
- optional `docker compose` and `git` target families

## Is It A Fit?

`almakefiles` is usable today when the consumer project runs on:

- GNU Make
- Bash 4.3+
- GNU userland tools such as `realpath --relative-base`, `find -printf`, and `chmod --reference`

Linux and WSL are the intended environments.
Stock macOS is not supported out of the box.

## Quick Start

Put this line into the consumer project's Make entrypoint file, for example `GNUmakefile`, `Makefile`, or `makefile`.
It tells GNU Make to load the `almakefiles` drop-in layer before resolving the project's targets.

```make
include almakefiles/include.mk
```

Then run:

```bash
make help
```

If the project uses a non-default Make entrypoint filename:

```bash
make -f path/to/entrypoint help
```

## Read Next

- [`docs/getting-started.md`](docs/getting-started.md) for installation patterns and the first run
- [`docs/contracts.md`](docs/contracts.md) for public guarantees and runtime support
- [`docs/reference.md`](docs/reference.md) for the public variables and target families
- [`docs/architecture.md`](docs/architecture.md) for the internal startup flow
- [`docs/modules/common.md`](docs/modules/common.md), [`env.md`](docs/modules/env.md), [`docker-compose.md`](docs/modules/docker-compose.md), and [`git.md`](docs/modules/git.md) for module-specific behavior
