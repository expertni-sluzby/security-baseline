# baseline.yml — L1 scanners

Reusable workflow implementing L1 of [PLAN.md](PLAN.md) §7.1.

## Use

```yaml
# .github/workflows/security.yml in the consumer repo
name: security
on:
  pull_request:
  push:
    branches: [main, develop]
  schedule:
    - cron: "0 3 * * *"      # nightly: full-history secret scan, fresh advisories
  workflow_dispatch:
permissions: {}
jobs:
  baseline:
    uses: expertni-sluzby/security-baseline/.github/workflows/baseline.yml@v1
    permissions:
      contents: read
    with:
      defectdojo-url: ${{ vars.DEFECTDOJO_URL }}
      # enforce: true          # once the backlog is triaged
    secrets:                   # explicit, never `secrets: inherit`
      DEFECTDOJO_TOKEN: ${{ secrets.DEFECTDOJO_TOKEN }}
```

`DEFECTDOJO_URL` (variable) and `DEFECTDOJO_TOKEN` (secret) are set once per organization.
Make the `baseline / gate` check required with a branch ruleset.

## Inputs

| Input | Default | Meaning |
|---|---|---|
| `product` | repository name | DefectDojo product (created on first upload) |
| `product-type` | repository owner | DefectDojo product type = organization; the token can write only here |
| `defectdojo-url` | empty | empty = no upload |
| `enforce` | `false` | block on dependency / IaC / SAST / workflow findings at or above `fail-on` |
| `fail-on` | `high` | `high` or `critical` |

## What runs

| Job | Tool | Scope | Blocks |
|---|---|---|---|
| secrets | gitleaks, TruffleHog `--only-verified` | PR: the PR's commits · push: the pushed commits · schedule/dispatch: full history | **always** on PR/push; full-history hits are warnings |
| dependencies | osv-scanner | all lockfiles, recursive | with `enforce`: CVSS ≥ 7 (≥ 9 for `critical`) |
| iac | Trivy `config` | Dockerfile, Helm, Kubernetes, Terraform | with `enforce`: HIGH/CRITICAL |
| sast | Semgrep `p/default` | whole repo, `.semgrepignore` respected | with `enforce`: ERROR/HIGH/CRITICAL |
| workflows | zizmor | `.github/workflows/**` | with `enforce`: high |
| defectdojo | `reimport-scan` | not on pull requests | — (fails red if DefectDojo rejects an upload) |
| gate | — | — | the one check to require; a scanner job that did not finish fails it |

Each push / scheduled run updates one DefectDojo engagement per branch (`ci/<branch>`), one
test per tool; findings missing from a later run are closed. Secret findings are the exception:
a push scans only the pushed commits, so its upload adds and reopens secret findings but never
closes one; only a full-history scan (schedule, dispatch, a push without a usable base) closes
them.

A leaked secret that has been rotated stays in the git history and keeps being reported. Once it
is rotated (and only then), add its gitleaks fingerprint (`commit:file:rule:line`, in the run's
`baseline-secrets` artifact) to `.gitleaksignore` in the consumer repo; the next full-history
scan closes the finding.

## Supply chain

Scanners are release binaries (Semgrep: an image) pinned by version and sha256 and at least
14 days old when pinned; actions are pinned by commit SHA; no third-party scanner actions;
no `${{ }}` inside `run:`. Reports are artifacts (public on a public repo): gitleaks runs with
`--redact`, TruffleHog values are replaced before upload.

## Not yet (v1.x)

Our own Semgrep packs (`rules/semgrep/`), Trivy image scans, SBOM, gating on *new* findings only
(today `enforce` blocks on every finding at the threshold — start with `enforce: false`),
Harden-Runner `block` mode with an egress allowlist.
