# security-baseline: notes for agents

Reusable L1 security workflow (`.github/workflows/baseline.yml`) for every repository of the company, plus the plan for the
other layers (`docs/PLAN.md`). Contract and usage: `docs/baseline.md`. The repository is public and every consumer hands
it secrets, so it is a supply-chain target (`docs/PLAN.md` §6).

## Rules

- Scanners are pinned by version **and** sha256 (Semgrep: an image by digest, through the company Harbor's proxy of
  Docker Hub), actions by commit SHA; versions are at least 14 days old when pinned. No third-party scanner actions, no
  `${{ }}` inside `run:`, no `pull_request_target`, minimal `permissions:`.
- `main` takes changes only through pull requests reviewed by the code owner (ruleset `main-protection`). Tags `v*` are
  immutable. Versioning is semver: a rule change that can newly fail consumers' builds is a minor bump, a contract change
  is a major bump. Every tag gets a GitHub release with notes in Czech, like the existing ones.
- Docs are in English.

## The consumer list must be maintained

`docs/consumers.md` lists every repository that calls `baseline.yml` and the version it pins. **Keep it current, in the
same piece of work as the change that makes it stale:**

- a repository starts or stops using the baseline, or changes its runner or DefectDojo product: update its row;
- a consumer moves its pin: update the pin in its row;
- a release here: update "Current release", note which consumers are behind, and before tagging re-run the code search
  in `docs/consumers.md` to find consumers the list misses.

A pull request that releases a version or changes a consumer without updating the list is not finished.
