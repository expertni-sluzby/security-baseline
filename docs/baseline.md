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
| dependencies | osv-scanner | all lockfiles, recursive; a root `osv-scanner.toml` applies to all of them | with `enforce`: CVSS ≥ 7 (≥ 9 for `critical`) |
| iac | Trivy `config` | Dockerfile, Helm, Kubernetes, Terraform | with `enforce`: HIGH/CRITICAL |
| sast | Semgrep `p/default` | whole repo, `.semgrepignore` respected | with `enforce`: ERROR/HIGH/CRITICAL |
| workflows | zizmor | `.github/workflows/**` | with `enforce`: high |
| defectdojo | `reimport-scan` | not on pull requests | — (fails red if DefectDojo rejects an upload) |
| gate | — | — | the one check to require; names what blocked, where the full list is and what to do (see *Reading a failed run*); a scanner job that did not finish fails it |

Each push / scheduled run updates one DefectDojo engagement per branch (`ci/<branch>`), one
test per tool; findings missing from a later run are closed. Secret findings are the exception:
a push scans only the pushed commits, so its upload adds and reopens secret findings but never
closes one; only a full-history scan (schedule, dispatch, a push without a usable base) closes
them.

A leaked secret that has been rotated stays in the git history and keeps being reported. Once it
is rotated (and only then), add its gitleaks fingerprint (`commit:file:rule:line`, in the run's
`baseline-secrets` artifact) to `.gitleaksignore` in the consumer repo; the next full-history
scan closes the finding.

A dependency advisory whose vulnerable code the consumer cannot reach is ignored in
`osv-scanner.toml` at the repository root (`[[IgnoredVulns]]` with `id`, `reason` and an
`ignoreUntil` date, after which it is reported again). osv-scanner itself reads such a file only
next to each lockfile, so the workflow passes the root one with `--config`, covering every
lockfile. An advisory that is merely inconvenient is not ignored: it is fixed, or accepted in
DefectDojo.

## Reading a failed run

Only the gate turns red; the scanner jobs stay green and carry the detail. Look, in this order, at:

1. **The annotations** of the run (on a pull request also in the Checks tab). The gate names what
   blocked, with the first three findings, the threshold and the fix, e.g.
   `1 advisory at or above CVSS 7.0 in 4 lockfiles: SixLabors.ImageSharp@3.1.11 GHSA-v76p-62qx-wwq2 (CVSS 7.5, fixed in 3.2.0, 4.1.1)`.
   Each scanner job annotates its blocking findings (the first ten) on the file and line.
2. **The Summary page** of the run: a section per scanner with the full table (advisory, fixed
   version and lockfiles; check, location and resolution; rule, location and message) and the fix
   that applies, and a *Gate* section with the verdict per scanner.
3. **The artifacts** `baseline-*`: the raw reports, kept 7 days, for tooling.

On a pull request the scanners look at the whole repository at the PR's head, not only at its
changes, so a blocking finding may predate the PR: an advisory published yesterday blocks every
branch today. Fix it in the PR, or merge the fix to the base branch and update the branch
(gating on new findings only: see *Not yet*).

| Scanner | Fix | Confirmed false positive, accepted risk |
|---|---|---|
| secrets | rotate first, then remove from the code (PLAN.md §8) | once rotated: the fingerprint in `.gitleaksignore` (above) |
| dependencies | upgrade to the fixed version the table shows | unreachable code: `osv-scanner.toml` (above); merely inconvenient: accept in DefectDojo |
| iac | as the resolution says | the check ID in `.trivyignore`, with a comment saying why |
| sast | as the rule says | `nosemgrep: <rule-id>` on the line; a path in `.semgrepignore` |
| workflows | as the audit says ([docs.zizmor.sh/audits](https://docs.zizmor.sh/audits/)) | `# zizmor: ignore[<audit>]` on the line |

## Supply chain

Scanners are release binaries (Semgrep: an image) pinned by version and sha256 and at least
14 days old when pinned; actions are pinned by commit SHA; no third-party scanner actions;
no `${{ }}` inside `run:`. Reports are artifacts (public on a public repo): gitleaks runs with
`--redact`, TruffleHog values are replaced before upload.

## Not yet (v1.x)

Our own Semgrep packs (`rules/semgrep/`), Trivy image scans, SBOM, gating on *new* findings only
(today `enforce` blocks on every finding at the threshold — start with `enforce: false`),
Harden-Runner `block` mode with an egress allowlist.
