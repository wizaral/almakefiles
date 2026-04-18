# Repository Guidelines

## Repository Role

- This repository is the `almakefiles` drop-in layer and its self-hosted end-to-end tests.
- Treat `README.md` and `docs/*.md` as the product documentation surface.

## Documentation Boundaries

- `README.md`
    - landing page for a first-time visitor
- `docs/getting-started.md`
    - onboarding and first-run expectations
- `docs/contracts.md`
    - public guarantees that consumer projects may rely on
- `docs/reference.md`
    - quick lookup for the public surface
- `docs/architecture.md`
    - internal startup flow and cross-module mechanics
- `docs/modules/*.md`
    - module-specific public behavior
- `AGENTS.md`
    - contributor and agent workflow guidance only

Do not duplicate user-facing contracts here when the repository docs already define them.

## Source Of Truth

- `include.mk`
    - entrypoint loading order and duplicate-entrypoint protection
- `mk/common.mk`
    - canonical path detection, module discovery, early `.env.mk` bootstrap, shared Make helpers, post-include hooks
- `mk/env.mk`
    - regular `.env*` initialization and env-related public targets
- `mk/docker-compose.mk`
    - compose defaults and generated compose targets
- `mk/git.mk`
    - git clean targets and exclusion handling
- `scripts/env-make.sh`
    - `.env.mk` validation, rebuild, sync, and debug reports
- `scripts/env-init.sh`
    - regular `.env*` initialization and provenance handling
- `scripts/help.sh`
    - active-target filtering and final help rendering order
- `tests/suites/*.sh`
    - end-to-end contract coverage

## Working Rules

- Keep product-facing rules in the repository docs instead of re-explaining them in code comments or contributor docs.
- Update the matching module document when module behavior changes.
- Update `docs/contracts.md` only when a real public guarantee changes.
- Update `docs/reference.md` when the public surface changes.
- Update `docs/architecture.md` when startup flow, discovery, scan rules, or target materialization logic change.
- Keep `README.md` small and usable as a landing page.

## Verification

Run after behavioral changes:

```bash
bash tests/test_make_templates.sh
```

Run shell checks after script or test changes:

```bash
shellcheck -x -P tests scripts/env-init.sh scripts/env-make.sh scripts/help.sh scripts/lib/common.sh tests/lib/test_helpers.sh tests/suites/env-init-suite.sh tests/suites/env-make-suite.sh tests/suites/system-suite.sh tests/test_make_templates.sh
```

## Commit Messages

- Use a short `subject`.
- Add a `body` when the reason, scope, or contract impact needs explanation.
- Describe what the commit changes in the repository, not issue-tracker bookkeeping.
